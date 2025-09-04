const std = @import("std");
const Frame = @import("Frame.zig").Frame;
const config = @import("../config.zig");

pub const FramePair = struct {
    depth_timestamp: u32,
    rgb_timestamp: u32,

    pub fn generate(allocator: std.mem.Allocator) ![]FramePair {
        const depth_timestamps = try readTimestamps(allocator, "./kinect_output/depth/");
        defer allocator.free(depth_timestamps);

        const rgb_timestamps = try readTimestamps(allocator, "./kinect_output/rgb/");
        defer allocator.free(rgb_timestamps);

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
                try matches.append(allocator, .{ .depth_timestamp = ts_d, .rgb_timestamp = ts_r });
                i += 1;
                j += 1;
            } else if (ts_d < ts_r) {
                // depth frame too far behind
                i += 1;
            } else {
                // rgb frame too far behind
                j += 1;
            }
        }

        return try matches.toOwnedSlice(allocator);
    }

    pub fn getDepthFrame(self: @This(), allocator: std.mem.Allocator) !Frame {
        var filename_buf: [128]u8 = undefined;
        const filename = try std.fmt.bufPrint(
            &filename_buf,
            "{s}/depth/{d}.pgm",
            .{ config.OUTPUT_LOCATION, self.depth_timestamp },
        );

        var file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var line_buf: [1024]u8 = undefined;
        var file_reader = file.reader(&line_buf);
        const r = &file_reader.interface;

        const magic_number = try r.takeDelimiterExclusive('\n');
        if (!std.mem.eql(u8, magic_number, "P5")) {
            return error.InvalidFormat;
        }

        var dims: ?[]const u8 = null;
        while (dims == null) {
            const line = try r.takeDelimiterExclusive('\n');
            if (line.len > 0 and line[0] != '#') {
                dims = line;
            }
        }

        var it = std.mem.tokenizeScalar(u8, dims.?, ' ');
        const width = try std.fmt.parseInt(u32, it.next().?, 10);
        const height = try std.fmt.parseInt(u32, it.next().?, 10);

        const max_val_line = try r.takeDelimiterExclusive('\n');
        const max_val = try std.fmt.parseInt(u32, max_val_line, 10);
        if (max_val != 65535) return error.UnsupportedFormat;

        const depth_buf = try allocator.alloc(u16, width * height);
        const raw_bytes = std.mem.sliceAsBytes(depth_buf);
        _ = try file.readAll(raw_bytes);

        // PGM stores big-endian 16-bit values; swap to little-endian
        for (depth_buf) |*d| {
            d.* = @as(u16, @byteSwap(d.*));
        }

        return Frame{
            .depth = .{
                .width = width,
                .height = height,
                .timestamp = self.depth_timestamp,
                .data = depth_buf,
            },
        };
    }

    pub fn getRgbFrame(self: @This(), allocator: std.mem.Allocator) !Frame {
        var filename_buf: [128]u8 = undefined;
        const filename = try std.fmt.bufPrint(
            &filename_buf,
            "{s}/rgb/{d}.ppm",
            .{ config.OUTPUT_LOCATION, self.rgb_timestamp },
        );

        var file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var line_buf: [1024]u8 = undefined;
        var file_reader = file.reader(&line_buf);
        const r = &file_reader.interface;

        const magic_number = try r.takeDelimiterExclusive('\n');
        if (!std.mem.eql(u8, magic_number, "P6")) return error.InvalidFormat;

        var dims: ?[]const u8 = null;
        while (dims == null) {
            const line = try r.takeDelimiterExclusive('\n');
            if (line.len > 0 and line[0] != '#') {
                dims = line;
            }
        }

        var it = std.mem.tokenizeScalar(u8, dims.?, ' ');
        const width = try std.fmt.parseInt(u32, it.next().?, 10);
        const height = try std.fmt.parseInt(u32, it.next().?, 10);

        const max_val_line = try r.takeDelimiterExclusive('\n');
        const max_val = try std.fmt.parseInt(u32, max_val_line, 10);
        if (max_val != 255) return error.UnsupportedFormat;

        const pixels_buf = try allocator.alloc(u8, width * height * 3);
        _ = try file.readAll(pixels_buf);

        return Frame{
            .rgb = .{
                .width = width,
                .height = height,
                .timestamp = self.rgb_timestamp,
                .data = pixels_buf,
            },
        };
    }
};
