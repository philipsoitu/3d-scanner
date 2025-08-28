const std = @import("std");

const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

const Frame = struct {
    data: []u8,
    index: usize,
    width: usize,
    height: usize,
    channels: usize, // 3 for RGB, 2 for depth (16-bit)
    kind: Kind,
};

const Kind = enum { rgb, depth };

/// Thread-safe blocking queue
const Queue = struct {
    allocator: *std.mem.Allocator,
    list: std.ArrayList(Frame),
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    done: bool = false,

    pub fn init(allocator: *std.mem.Allocator) Queue {
        return Queue{
            .allocator = allocator,
            .list = std.ArrayList(Frame).init(allocator.*),
        };
    }

    pub fn deinit(self: *Queue) void {
        self.list.deinit();
    }

    pub fn push(self: *Queue, frame: Frame) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.list.append(frame);
        self.cond.signal();
    }

    pub fn pop(self: *Queue) ?Frame {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.list.items.len == 0 and !self.done) {
            self.cond.wait(&self.mutex);
        }

        if (self.list.items.len == 0 and self.done) {
            return null;
        }

        return self.list.orderedRemove(0);
    }

    pub fn finish(self: *Queue) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.done = true;
        self.cond.broadcast();
    }
};

/// Simple buffer pool
const BufferPool = struct {
    allocator: *std.mem.Allocator,
    free_list: std.ArrayList([]u8),
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},

    pub fn init(allocator: *std.mem.Allocator, count: usize, size: usize) !BufferPool {
        var pool = BufferPool{
            .allocator = allocator,
            .free_list = std.ArrayList([]u8).init(allocator.*),
        };
        try pool.free_list.ensureTotalCapacity(count);
        for (0..count) |_| {
            const buf = try allocator.alloc(u8, size);
            try pool.free_list.append(buf);
        }
        return pool;
    }

    pub fn deinit(self: *BufferPool) void {
        for (self.free_list.items) |buf| {
            self.allocator.free(buf);
        }
        self.free_list.deinit();
    }

    pub fn acquire(self: *BufferPool) []u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.free_list.items.len == 0) {
            self.cond.wait(&self.mutex);
        }
        return self.free_list.pop();
    }

    pub fn release(self: *BufferPool, buf: []u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.free_list.append(buf) catch unreachable;
        self.cond.signal();
    }
};

/// Context for consumer
const ConsumerCtx = struct {
    queue: *Queue,
    pool: *BufferPool,
    prefix: []const u8,
    kind: Kind,
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
        var maybe_frame = ctx.queue.pop();
        if (maybe_frame == null) break;

        var frame = maybe_frame.?;

        var filename_buf: [64]u8 = undefined;
        const ext = switch (frame.kind) {
            .rgb => ".ppm",
            .depth => ".pgm",
        };
        const filename = try std.fmt.bufPrint(
            &filename_buf,
            "{s}_{d:06}{s}",
            .{ ctx.prefix, frame.index, ext },
        );

        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        // Write header
        switch (frame.kind) {
            .rgb => {
                try file.writer().print("P6\n{d} {d}\n255\n", .{ frame.width, frame.height });
            },
            .depth => {
                try file.writer().print("P5\n{d} {d}\n65535\n", .{ frame.width, frame.height });
            },
        }

        // Write raw pixels
        try file.writeAll(frame.data);

        ctx.pool.release(frame.data);
    }
}

/// Callback: RGB
export fn rgb_callback(dev: ?*c.freenect_device, rgb: ?*c_void, timestamp: u32) callconv(.C) void {
    _ = timestamp;
    if (dev == null or rgb == null) return;

    const user = c.freenect_get_user(dev);
    if (user == null) return;
    var ctx = @ptrCast(*DeviceCtx, @alignCast(@alignOf(*DeviceCtx), user));

    const width = 640;
    const height = 480;
    const frame_size = width * height * 3;

    var buf = ctx.rgb_pool.acquire();
    std.mem.copy(u8, buf, @ptrCast([*]u8, rgb)[0..frame_size]);

    ctx.rgb_queue.push(Frame{
        .data = buf,
        .index = ctx.rgb_index,
        .width = width,
        .height = height,
        .channels = 3,
        .kind = .rgb,
    }) catch {};
    ctx.rgb_index += 1;
}

/// Callback: Depth
export fn depth_callback(dev: ?*c.freenect_device, depth: ?*c_void, timestamp: u32) callconv(.C) void {
    _ = timestamp;
    if (dev == null or depth == null) return;

    const user = c.freenect_get_user(dev);
    if (user == null) return;
    var ctx = @ptrCast(*DeviceCtx, @alignCast(@alignOf(*DeviceCtx), user));

    const width = 640;
    const height = 480;
    const frame_size = width * height * 2;

    var buf = ctx.depth_pool.acquire();
    std.mem.copy(u8, buf, @ptrCast([*]u8, depth)[0..frame_size]);

    ctx.depth_queue.push(Frame{
        .data = buf,
        .index = ctx.depth_index,
        .width = width,
        .height = height,
        .channels = 1,
        .kind = .depth,
    }) catch {};
    ctx.depth_index += 1;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

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

    var rgb_ctx = ConsumerCtx{ .queue = &rgb_queue, .pool = &rgb_pool, .prefix = "rgb", .kind = .rgb };
    var depth_ctx = ConsumerCtx{ .queue = &depth_queue, .pool = &depth_pool, .prefix = "depth", .kind = .depth };

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
    defer c.freenect_shutdown(ctx);

    c.freenect_set_log_level(ctx, c.FREENECT_LOG_INFO);

    var dev: ?*c.freenect_device = null;
    if (c.freenect_open_device(ctx, &dev, 0) < 0 or dev == null) return error.OpenFailed;
    defer c.freenect_close_device(dev);

    // Pass pointer to our context
    c.freenect_set_user(dev, &dev_ctx);

    // Set callbacks
    c.freenect_set_video_callback(dev, rgb_callback);
    c.freenect_set_depth_callback(dev, depth_callback);

    // Configure streams
    _ = c.freenect_set_video_format(dev, c.FREENECT_VIDEO_RGB);
    _ = c.freenect_set_depth_format(dev, c.FREENECT_DEPTH_11BIT);

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
