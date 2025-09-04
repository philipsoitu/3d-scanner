const std = @import("std");
const point_cloud = @import("point_cloud.zig");
const config = @import("config.zig");

const Frame = @import("types/Frame.zig").Frame;
const FramePair = @import("types/FramePair.zig").FramePair;

pub fn run(allocator: std.mem.Allocator) !void {

    // match nearest depth and rgb frames to each other
    const pairs = try FramePair.generate(allocator);
    defer allocator.free(pairs);
    std.debug.print("pairs: {}\n", .{pairs.len});

    for (pairs, 0..pairs.len) |pair, i| {
        std.debug.print("{d} depth: {}, rgb: {}\n", .{ i + 1, pair.depth_timestamp, pair.rgb_timestamp });

        // filename
        var filename_buf: [256]u8 = undefined;
        const filename = try std.fmt.bufPrint(
            &filename_buf,
            "{s}/pointcloud/d{d}_r{d}.ply",
            .{ config.OUTPUT_LOCATION, pair.depth_timestamp, pair.rgb_timestamp },
        );

        // generate pointcloud
        const point = try point_cloud.framePairToPointCloud(allocator, &pair);
        defer allocator.free(point);

        try point_cloud.writePLY(point, filename);

        //TODO: Write save to disk funcction
        //        _ = pointcloud;
    }

    //TODO: Run ICP code to generate final pointcloud

}
