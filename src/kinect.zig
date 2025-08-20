const std = @import("std");
const Frame = @import("frame.zig").Frame;
const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

pub const Kinect = struct {
    ctx: ?*c.freenect_context,
    dev: ?*c.freenect_device,

    pub fn init() !Kinect {
        var k = Kinect{
            .ctx = null,
            .dev = null,
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

        return k;
    }

    pub fn shutdown(self: *Kinect) void {
        _ = c.freenect_close_device(self.dev);
        _ = c.freenect_shutdown(self.ctx);
    }
};
