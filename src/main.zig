const std = @import("std");
const kinect = @import("kinect.zig");
const Frame = @import("frame.zig").Frame;

pub fn main() !void {
    var frame = Frame.init(640, 480);

    var starting_state = kinect.KinectState{
        .depth_captured = false,
        .rgb_captured = false,
        .frame = &frame,
    };

    var k: kinect.Kinect = try kinect.Kinect.init(&starting_state);
    defer k.shutdown();

    try k.runLoop();

    try frame.save_depth_pgm("kinect_output/depth.pgm");
    try frame.save_rgb_ppm("kinect_output/rgb.ppm");
}
