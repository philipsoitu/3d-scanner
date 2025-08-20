const std = @import("std");
const kinect = @import("kinect.zig");

const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

pub fn main() !void {
    var k: kinect.Kinect = try kinect.Kinect.init();
    defer k.shutdown();

    try k.runLoop();

    std.debug.print("done\n", .{});
}
