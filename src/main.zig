const std = @import("std");
const kinect = @import("kinect.zig");
const Frame = @import("frame.zig").Frame;
const point_cloud = @import("point_cloud.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var frame = Frame.init(640, 480);

    var starting_state = kinect.KinectState{
        .depth_captured = false,
        .rgb_captured = false,
        .frame = &frame,
    };

    var k: kinect.Kinect = try kinect.Kinect.init(&starting_state);
    try k.runLoop();
    defer k.shutdown();

    try frame.save_depth_pgm("kinect_output/depth.pgm");
    try frame.save_rgb_ppm("kinect_output/rgb.ppm");

    const points = try point_cloud.frameToPoints(allocator, &frame);
    defer allocator.free(points);

    try point_cloud.writePLY(points, "pointcloud.ply");
}
