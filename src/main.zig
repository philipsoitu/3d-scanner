const std = @import("std");
const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

pub fn main() !void {
    std.debug.print("libfreenect init test\n", .{});

    var ctx: ?*c.freenect_context = null;
    if (c.freenect_init(&ctx, null) < 0) {
        std.debug.print("freenext init failed\n", .{});
        return;
    }

    defer _ = c.freenect_shutdown(ctx);

    const num_devices = c.freenect_num_devices(ctx);
    std.debug.print("num_devices: {d}\n", .{num_devices});

    std.debug.print("freenect_init succeeded: {any}\n", .{ctx});
}
