const std = @import("std");
const Frame = @import("frame.zig").Frame;
const Queue = @import("Queue.zig").Queue;
const BufferPool = @import("BufferPool.zig").BufferPool;
const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

pub const KinectCtx = struct {
    rgb_queue: *Queue,
    rgb_pool: *BufferPool,
    rgb_index: usize,
    depth_queue: *Queue,
    depth_pool: *BufferPool,
    depth_index: usize,
};

pub const Kinect = struct {
    ctx: ?*c.freenect_context,
    dev: ?*c.freenect_device,

    pub fn init(kinect_ctx: *KinectCtx) !Kinect {
        var k = Kinect{
            .ctx = null,
            .dev = null,
        };

        // init context
        if (c.freenect_init(&k.ctx, null) < 0) {
            return error.InitFailed;
        }

        // set logs
        c.freenect_set_log_level(k.ctx, c.FREENECT_LOG_DEBUG);
        c.freenect_select_subdevices(k.ctx, c.FREENECT_DEVICE_CAMERA);

        // get num of device
        const num_devices = c.freenect_num_devices(k.ctx);
        if (num_devices == 0) {
            _ = c.freenect_shutdown(k.ctx);
            return error.NoDevice;
        }

        // connect to device
        if (c.freenect_open_device(k.ctx, &k.dev, 0) != 0) {
            _ = c.freenect_shutdown(k.ctx);
            return error.DeviceOpenFailed;
        }

        c.freenect_set_user(k.dev, kinect_ctx);

        // set modes
        _ = c.freenect_set_depth_mode(k.dev, c.freenect_find_depth_mode(
            c.FREENECT_RESOLUTION_LOW,
            c.FREENECT_DEPTH_MM,
        ));
        _ = c.freenect_set_video_mode(k.dev, c.freenect_find_video_mode(
            c.FREENECT_RESOLUTION_LOW,
            c.FREENECT_VIDEO_RGB,
        ));

        // set callbacks
        c.freenect_set_depth_callback(k.dev, depth_callback);
        c.freenect_set_video_callback(k.dev, rgb_callback);

        // start streams
        _ = c.freenect_start_depth(k.dev);
        _ = c.freenect_start_video(k.dev);

        return k;
    }

    pub fn runLoop(self: *Kinect) !void {
        const start_time = std.time.milliTimestamp();
        while (std.time.milliTimestamp() - start_time < 5_000) {
            const result = c.freenect_process_events(self.ctx);
            if (result < 0) {
                return error.EventLoopFailed;
            }
        }
    }

    pub fn shutdown(self: *Kinect) void {
        _ = c.freenect_stop_depth(self.dev);
        _ = c.freenect_stop_video(self.dev);
        _ = c.freenect_close_device(self.dev);
        _ = c.freenect_shutdown(self.ctx);
    }
};

export fn rgb_callback(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.c) void {
    if (dev == null) return;

    const user = c.freenect_get_user(dev);
    if (user == null) return;
    var ctx = @as(*KinectCtx, @ptrCast(@alignCast(user)));

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

export fn depth_callback(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.c) void {
    if (dev == null or data == null) return;

    const user = c.freenect_get_user(dev);
    if (user == null) return;
    var ctx = @as(*KinectCtx, @ptrCast(@alignCast(user)));

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
