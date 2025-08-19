const std = @import("std");
const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

pub fn main() !void {
    var ctx: ?*c.freenect_context = null;
    if (c.freenect_init(&ctx, null) < 0) {
        std.debug.print("freenext init failed\n", .{});
        return;
    }

    defer _ = c.freenect_shutdown(ctx);

    const num_devices = c.freenect_num_devices(ctx);
    std.debug.print("num_devices: {d}\n", .{num_devices});

    if (num_devices > 0) {
        var dev: ?*c.freenect_device = null;
        if (c.freenect_open_device(ctx, &dev, 0) == 0) {
            std.debug.print("lets goo\n", .{});
            _ = c.freenect_close_device(dev);
        }
    }
}
