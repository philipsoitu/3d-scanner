const std = @import("std");
const Frame = @import("frame.zig").Frame;
const kinect = @import("kinect.zig");
const out = @import("out.zig");

pub fn main() !void {
    var k = try kinect.Kinect.init();
    defer k.shutdown();
}
