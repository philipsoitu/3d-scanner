const std = @import("std");
const Frame = @import("frame.zig").Frame;
const kinect = @import("kinect.zig");
const out = @import("out.zig");

pub fn main() !void {
    var k = try kinect.Kinect.init();
    std.debug.print("yoo: {any}\n", .{k});
    defer k.shutdown();
}
