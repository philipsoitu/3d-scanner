const std = @import("std");
const kinect = @import("kinect.zig");

const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

pub fn main() !void {
    var starting_state = kinect.KinectState{
        .depth_captured = false,
        .rgb_captured = false,
    };

    var k: kinect.Kinect = try kinect.Kinect.init(&starting_state);
    defer k.shutdown();

    try k.runLoop();

    std.debug.print("done\n", .{});
}
