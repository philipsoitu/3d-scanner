const std = @import("std");
const Frame = @import("frame.zig").Frame;
const FrameType = @import("frame.zig").FrameType;
const Queue = @import("Queue.zig").Queue;
const BufferPool = @import("BufferPool.zig").BufferPool;

const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

/// Context for consumer
const ConsumerCtx = struct {
    queue: *Queue,
    pool: *BufferPool,
    prefix: []const u8,
    frame_type: FrameType,
};

/// Global device context
const DeviceCtx = struct {
    rgb_queue: *Queue,
    rgb_pool: *BufferPool,
    rgb_index: usize,
    depth_queue: *Queue,
    depth_pool: *BufferPool,
    depth_index: usize,
};

fn consumerThread(ctx: *ConsumerCtx) !void {
    while (true) {
        const maybe_frame = ctx.queue.pop();
        if (maybe_frame == null) break;

        const frame = maybe_frame.?;

        var filename_buf: [64]u8 = undefined;
        const ext = switch (frame.type) {
            .Rgb => ".ppm",
            .Depth => ".pgm",
        };
        const filename = try std.fmt.bufPrint(
            &filename_buf,
            "{s}_{d}{s}",
            .{ ctx.prefix, frame.timestamp, ext },
        );

        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        var writer_buf: [4096]u8 = undefined;
        var file_writer = file.writer(&writer_buf);
        const w = &file_writer.interface;

        // Write header
        switch (frame.type) {
            .Rgb => {
                try w.print("P6\n{d} {d}\n255\n", .{ frame.width, frame.height });
            },
            .Depth => {
                try w.print("P5\n{d} {d}\n65535\n", .{ frame.width, frame.height });
            },
        }

        // Write raw pixels
        try w.writeAll(frame.data);

        ctx.pool.release(frame.data);

        try w.flush();
    }
}

/// Callback: RGB
export fn rgb_callback(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.c) void {
    if (dev == null) return;

    const user = c.freenect_get_user(dev);
    if (user == null) return;
    var ctx = @as(*DeviceCtx, @ptrCast(@alignCast(user)));

    const width = 640;
    const height = 480;

    const buf = ctx.rgb_pool.acquire();
    const raw_data = data.?;
    const slice = @as([*]const u8, @ptrCast(raw_data))[0..buf.len];
    @memcpy(buf, slice);

    ctx.rgb_queue.push(Frame{
        .data = buf,
        .timestamp = timestamp,
        .width = width,
        .height = height,
        .type = .Rgb,
    }) catch {};
    ctx.rgb_index += 1;
}

/// Callback: Depth
export fn depth_callback(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.c) void {
    if (dev == null or data == null) return;

    const user = c.freenect_get_user(dev);
    if (user == null) return;
    var ctx = @as(*DeviceCtx, @ptrCast(@alignCast(user)));

    const width = 640;
    const height = 480;

    const buf = ctx.depth_pool.acquire();
    const raw_data = data.?;
    const slice = @as([*]const u8, @ptrCast(raw_data))[0..buf.len];
    @memcpy(buf, slice);

    ctx.depth_queue.push(Frame{
        .data = buf,
        .timestamp = timestamp,
        .width = width,
        .height = height,
        .type = .Depth,
    }) catch {};
    ctx.depth_index += 1;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const rgb_size = 640 * 480 * 3;
    const depth_size = 640 * 480 * 2;
    const pool_size = 8;

    var rgb_pool = try BufferPool.init(allocator, pool_size, rgb_size);
    defer rgb_pool.deinit();
    var depth_pool = try BufferPool.init(allocator, pool_size, depth_size);
    defer depth_pool.deinit();

    var rgb_queue = Queue.init(allocator);
    defer rgb_queue.deinit();
    var depth_queue = Queue.init(allocator);
    defer depth_queue.deinit();

    var rgb_ctx = ConsumerCtx{ .queue = &rgb_queue, .pool = &rgb_pool, .prefix = "rgb", .frame_type = .Rgb };
    var depth_ctx = ConsumerCtx{ .queue = &depth_queue, .pool = &depth_pool, .prefix = "depth", .frame_type = .Depth };

    var rgb_consumer = try std.Thread.spawn(.{}, consumerThread, .{&rgb_ctx});
    var depth_consumer = try std.Thread.spawn(.{}, consumerThread, .{&depth_ctx});

    var dev_ctx = DeviceCtx{
        .rgb_queue = &rgb_queue,
        .rgb_pool = &rgb_pool,
        .rgb_index = 0,
        .depth_queue = &depth_queue,
        .depth_pool = &depth_pool,
        .depth_index = 0,
    };

    // Init libfreenect
    var ctx: ?*c.freenect_context = null;
    if (c.freenect_init(&ctx, null) < 0 or ctx == null) return error.InitFailed;
    defer _ = c.freenect_shutdown(ctx);

    c.freenect_set_log_level(ctx, c.FREENECT_LOG_INFO);

    var dev: ?*c.freenect_device = null;
    if (c.freenect_open_device(ctx, &dev, 0) < 0 or dev == null) return error.OpenFailed;
    defer _ = c.freenect_close_device(dev);

    // Pass pointer to our context
    c.freenect_set_user(dev, &dev_ctx);

    // Set callbacks
    c.freenect_set_video_callback(dev, rgb_callback);
    c.freenect_set_depth_callback(dev, depth_callback);

    // Configure streams
    _ = c.freenect_set_depth_mode(dev, c.freenect_find_depth_mode(
        c.FREENECT_RESOLUTION_MEDIUM,
        c.FREENECT_DEPTH_MM,
    ));
    _ = c.freenect_set_video_mode(dev, c.freenect_find_video_mode(
        c.FREENECT_RESOLUTION_MEDIUM,
        c.FREENECT_VIDEO_RGB,
    ));

    // Start streams
    _ = c.freenect_start_video(dev);
    _ = c.freenect_start_depth(dev);

    // Run event loop for ~10 seconds
    const start_time = std.time.milliTimestamp();
    while (std.time.milliTimestamp() - start_time < 10_000) {
        if (c.freenect_process_events(ctx) < 0) break;
    }

    // Stop streams
    _ = c.freenect_stop_video(dev);
    _ = c.freenect_stop_depth(dev);

    // Signal consumers and wait
    rgb_queue.finish();
    depth_queue.finish();

    rgb_consumer.join();
    depth_consumer.join();
}
