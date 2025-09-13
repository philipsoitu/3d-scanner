const std = @import("std");
const config = @import("../config.zig");
const Frame = @import("Frame.zig").Frame;
const FramePair = @import("FramePair.zig").FramePair;

const Point = packed struct {
    x: f64,
    y: f64,
    z: f64,
    r: u8,
    g: u8,
    b: u8,
};

pub const PointCloud = struct {
    points: []Point,

    pub fn fromFramePair(allocator: std.mem.Allocator, frames: *const FramePair) !@This() {
        const frame_depth = try frames.getDepthFrame(allocator);
        const depth_frame = frame_depth.depth;
        defer allocator.free(depth_frame.data);

        const frame_rgb = try frames.getRgbFrame(allocator);
        const rgb_frame = frame_rgb.rgb;
        defer allocator.free(rgb_frame.data);

        var points = try allocator.alloc(Point, depth_frame.width * depth_frame.height);
        var count: usize = 0;

        for (0..depth_frame.height) |v| {
            for (0..depth_frame.width) |u| {
                const idx = v * depth_frame.width + u;
                const z_mm = depth_frame.data[idx];
                if (z_mm == 0 or z_mm > 4500) continue;

                const z: f64 = @as(f64, @floatFromInt(z_mm)) / 1000.0; // mm to meters
                const x: f64 = ((@as(f64, @floatFromInt(u)) - config.DEPTH_CX) * z) / config.DEPTH_FX;
                const y: f64 = ((@as(f64, @floatFromInt(v)) - config.DEPTH_CY) * z) / config.DEPTH_FY;

                const rgb_idx = idx * 3;

                const r: u8 = rgb_frame.data[rgb_idx + 0];
                const g: u8 = rgb_frame.data[rgb_idx + 1];
                const b: u8 = rgb_frame.data[rgb_idx + 2];

                points[count] = Point{
                    .x = x,
                    .y = -y,
                    .z = -z,
                    .r = linearToSrgb(r),
                    .g = linearToSrgb(g),
                    .b = linearToSrgb(b),
                };
                count += 1;
            }
        }

        return @This(){
            .points = points[0..count],
        };
    }

    pub fn save(self: *const @This(), filename: []const u8) !void {
        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        var writer_buf: [4096]u8 = undefined;
        var file_writer = file.writer(&writer_buf);
        const w = &file_writer.interface;

        try w.print(
            "ply\nformat binary_little_endian 1.0\nelement vertex {d}\nproperty double x\nproperty double y\nproperty double z\nproperty uchar red\nproperty uchar green\nproperty uchar blue\nend_header\n",
            .{self.points.len},
        );

        for (self.points) |p| {
            try w.writeStruct(Point{
                .x = p.x,
                .y = p.y,
                .z = p.z,
                .r = p.r,
                .g = p.g,
                .b = p.b,
            }, std.builtin.Endian.little);
        }

        try w.flush();
    }

    pub fn open(allocator: std.mem.Allocator, filename: []const u8) !PointCloud {
        var file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var line_buf: [1024]u8 = undefined;
        var file_reader = file.reader(&line_buf);
        const r = &file_reader.interface;

        var verts: usize = 0;

        // header
        while (true) {
            const line = try r.takeDelimiterExclusive(&line_buf, '\n') orelse return error.InvalidPly;
            if (std.mem.startsWith(u8, line, "element vertex")) {
                var it = std.mem.tokenize(u8, line, " ");
                _ = it.next(); // "element"
                _ = it.next(); // "vertex"
                verts = try std.fmt.parseInt(usize, it.next().?, 10);
            } else if (std.mem.eql(u8, line, "end_header")) {
                break;
            }
        }

        var points = try allocator.alloc(Point, verts);
        for (0..verts) |i| {
            points[i] = try r.takeStruct(Point, .little);
        }
    }
};

fn linearToSrgb(c: u8) u8 {
    const f = @as(f64, @floatFromInt(c)) / 255.0;
    const srgb = if (f <= 0.0031308)
        12.92 * f
    else
        1.055 * std.math.pow(f64, f, 1.0 / 2.4) - 0.055;
    return @as(u8, @intFromFloat(std.math.clamp(srgb * 255.0, 0, 255)));
}
