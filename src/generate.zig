const std = @import("std");
const config = @import("config.zig");

const Frame = @import("types/Frame.zig").Frame;
const FramePair = @import("types/FramePair.zig").FramePair;
const PointCloud = @import("types/PointCloud.zig").PointCloud;

pub fn run(allocator: std.mem.Allocator) !void {

    // match nearest depth and rgb frames to each other
    const pairs = try FramePair.generate(allocator);
    defer allocator.free(pairs);

    // get thread counts
    const cpu_count = try std.Thread.getCpuCount();
    const chunk_size = (pairs.len + cpu_count - 1) / cpu_count;

    const threads = try allocator.alloc(std.Thread, cpu_count);
    defer allocator.free(threads);

    // const thread_width: usize = std.math.log10_int(cpu_count) + 1;
    // const chunk_width: usize = std.math.log10_int(chunk_size) + 1;

    // clear screen
    std.debug.print("\x1b[2J", .{});

    for (0..cpu_count) |t_id| {
        std.debug.print(
            "\x1b[{d};{d}HThread {d: >2}: {d: >3}/{d: >3}\n",
            .{ t_id + 1, 0, t_id, 0, chunk_size },
        );
    }

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

    std.debug.print(
        "\x1b[{d};1H",
        .{cpu_count + 1},
    );
}

fn worker(thread_id: usize, pairs: []const FramePair, allocator: std.mem.Allocator) !void {
    for (pairs, 0..pairs.len) |pair, i| {
        std.debug.print(
            "\x1b[{d};1HThread {d: >2}: {d: >3}/{d: >3}\n",
            .{ thread_id + 1, thread_id, i + 1, pairs.len },
        );

        // filename
        var filename_buf: [256]u8 = undefined;
        const filename = try std.fmt.bufPrint(
            &filename_buf,
            "{s}/pointcloud/{d}.ply",
            .{ config.OUTPUT_LOCATION, pair.depth_timestamp },
        );

        // generate pointcloud
        const pointcloud = try PointCloud.fromFramePair(allocator, &pair);
        defer allocator.free(pointcloud.points);

        try pointcloud.save(filename);
    }
}
