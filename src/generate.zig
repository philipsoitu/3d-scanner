const std = @import("std");
const config = @import("config.zig");

const Frame = @import("types/Frame.zig").Frame;
const FramePair = @import("types/FramePair.zig").FramePair;
const PointCloud = @import("types/PointCloud.zig").PointCloud;

pub fn run(allocator: std.mem.Allocator) !void {

    // match nearest depth and rgb frames to each other
    const pairs = try FramePair.generate(allocator);
    defer allocator.free(pairs);
    std.debug.print("pairs: {}\n", .{pairs.len});

    // get thread counts
    const cpu_count = try std.Thread.getCpuCount();
    const chunk_size = (pairs.len + cpu_count - 1) / cpu_count;

    const threads = try allocator.alloc(std.Thread, cpu_count);
    defer allocator.free(threads);

    // initialize threads
    for (threads, 0..) |*t, t_id| {
        const start = t_id * chunk_size;
        if (start >= pairs.len) break;
        const end = @min(start + chunk_size, pairs.len);
        const slice = pairs[start..end];

        t.* = try std.Thread.spawn(.{}, worker, .{ t_id, slice, allocator });
    }

    // start threads
    for (threads) |*t| {
        t.*.join();
    }
}

fn worker(thread_id: usize, pairs: []const FramePair, allocator: std.mem.Allocator) !void {
    for (pairs, 0..pairs.len) |pair, i| {
        std.debug.print(
            "thread:{d:0>2} frame:{d:0>3} depth: {}, rgb: {}\n",
            .{ thread_id, i + 1, pair.depth_timestamp, pair.rgb_timestamp },
        );

        // filename
        var filename_buf: [256]u8 = undefined;
        const filename = try std.fmt.bufPrint(
            &filename_buf,
            "{s}/pointcloud/d{d}_r{d}.ply",
            .{ config.OUTPUT_LOCATION, pair.depth_timestamp, pair.rgb_timestamp },
        );

        // generate pointcloud
        const pointcloud = try PointCloud.fromFramePair(allocator, &pair);
        defer allocator.free(pointcloud.points);

        try pointcloud.save(filename);
    }
}
