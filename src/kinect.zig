const std = @import("std");
const Frame = @import("frame.zig").Frame;
const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

const c_void = extern struct {};

pub const Kinect = struct {
    ctx: ?*c.freenect_context,
    dev: ?*c.freenect_device,

    rgb_buffer: ?[640 * 480 * 3]u8,
    depth_buffer: ?[640 * 480]u11,

    pub fn init() !Kinect {
        var k = Kinect{
            .ctx = null,
            .dev = null,
            .rgb_buffer = null,
            .depth_buffer = null,
        };

        if (c.freenect_init(&k.ctx, null) < 0) {
            return error.InitFailed;
        }

        const num_devices = c.freenect_num_devices(k.ctx);
        if (num_devices == 0) {
            _ = c.freenect_shutdown(k.ctx);
            return error.NoDevice;
        }

        if (c.freenect_open_device(k.ctx, &k.dev, 0) != 0) {
            _ = c.freenect_shutdown(k.ctx);
            return error.DeviceOpenFailed;
        }

        _ = c.freenect_set_user(k.dev, @as(?*c_void, @ptrCast(&k)));

        _ = c.freenect_set_video_callback(k.dev, rgbCallback);
        _ = c.freenect_set_depth_callback(k.dev, depthCallback);

        _ = c.freenect_start_video(k.dev);
        _ = c.freenect_start_depth(k.dev);

        return k;
    }

    pub fn shutdown(self: *Kinect) void {
        _ = c.freenect_close_device(self.dev);
        _ = c.freenect_shutdown(self.ctx);
    }
};

fn rgbCallback(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.C) void {
    _ = timestamp;
    const k = @as(*Kinect, @ptrCast(@alignCast(c.freenect_get_user(dev))));
    std.mem.copyForwards(u8, k.rgb_buffer[0..], data[0 .. 640 * 480 * 3]);
    k.rgb_ready = true;
}

fn depthCallback(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.C) void {
    _ = timestamp;
    const k = @as(*Kinect, @ptrCast(@alignCast(c.freenect_get_user(dev))));
    for (0..640 * 480, data[0 .. 640 * 480]) |i, val| {
        k.depth_buffer[i] = @as(u11, @intCast(val & 0x7FF));
    }
    k.depth_ready = true;
}
