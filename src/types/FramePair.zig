const std = @import("std");
const Frame = @import("Frame.zig").Frame;

pub const FramePair = struct {
    depth: u32,
    rgb: u32,

    pub fn generate(allocator: std.mem.Allocator) ![]FramePair {
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

        const depth_timestamps = try readTimestamps(allocator, "./kinect_output/depth/");
        defer allocator.free(depth_timestamps);
        std.debug.print("depth frames count: {d}\n", .{depth_timestamps.len});

        const rgb_timestamps = try readTimestamps(allocator, "./kinect_output/rgb/");
        defer allocator.free(rgb_timestamps);
        std.debug.print("rgb frames conut: {d}\n", .{rgb_timestamps.len});

        std.mem.sort(u32, depth_timestamps, {}, comptime std.sort.asc(u32));
        std.mem.sort(u32, rgb_timestamps, {}, comptime std.sort.asc(u32));

        const pairs = try matchAlignedFrames(allocator, depth_timestamps, rgb_timestamps, 30);
        return pairs;
    }

    fn readTimestamps(allocator: std.mem.Allocator, path: []const u8) ![]u32 {
        var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
        defer dir.close();

        var list = std.ArrayList(u32){};

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;

            if (std.mem.endsWith(u8, entry.name, ".ppm") or std.mem.endsWith(u8, entry.name, ".pgm")) {
                const dot_index = std.mem.lastIndexOfScalar(u8, entry.name, '.') orelse continue;
                const number_str = entry.name[0..dot_index];

                const ts = try std.fmt.parseInt(u32, number_str, 10);
                try list.append(allocator, ts);
            }
        }

        return try list.toOwnedSlice(allocator);
    }

    // TODO: Make this not be as strict (cuz im losing like 75% of the frames rn)
    fn matchAlignedFrames(
        allocator: std.mem.Allocator,
        depth: []const u32,
        rgb: []const u32,
        frame_hz: u32,
    ) ![]@This() {
        const expected_gap: u32 = @intFromFloat(1_000_000.0 / @as(f32, @floatFromInt(frame_hz)));
        const max_gap: u32 = expected_gap * 2;

        var matches = std.ArrayList(@This()){};

        var i: usize = 0;
        var j: usize = 0;

        while (i < depth.len and j < rgb.len) {
            const ts_d = depth[i];
            const ts_r = rgb[j];

            const diff = if (ts_d > ts_r) ts_d - ts_r else ts_r - ts_d;

            if (diff <= max_gap) {
                // good frame match
                try matches.append(allocator, .{ .depth = ts_d, .rgb = ts_r });
                i += 1;
                j += 1;
            } else if (ts_d < ts_r) {
                // depth frame too far behind → drop it
                i += 1;
            } else {
                // rgb frame too far behind → drop it
                j += 1;
            }
        }

        return try matches.toOwnedSlice(allocator);
    }
};
