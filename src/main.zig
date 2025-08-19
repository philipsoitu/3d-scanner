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

    std.debug.print("freenect_init succeeded: {any}\n", .{ctx});

    _ = c.freenect_shutdown(ctx);
}
