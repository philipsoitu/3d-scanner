const std = @import("std");
const Frame = @import("types/Frame.zig").Frame;
const FramePair = @import("types/FramePair.zig").FramePair;

pub fn run(allocator: std.mem.Allocator) !void {
    //TODO:
    // get list of frames of each type
    // match nearest depth and rgb frames to each other
    // generate cloud point of first frame
    // while theres a frame remaining
    //      get next frame
    //      generate pointcloud
    //      icp both pointclouds
    //      save to global ply
    std.debug.print("generate starting \n", .{});
    const pairs = try FramePair.generate(allocator);
    defer allocator.free(pairs);
    std.debug.print("pairs: {}", .{pairs.len});
}
