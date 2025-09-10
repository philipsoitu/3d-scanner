const std = @import("std");
const Frame = @import("types/Frame.zig").Frame;
const FramePair = @import("types/FramePair.zig").FramePair;

const config = @import("config.zig");
const depth_fx = @import("config.zig").DEPTH_FX;
const depth_fy = @import("config.zig").DEPTH_FY;
const depth_cx = @import("config.zig").DEPTH_CX;
const depth_cy = @import("config.zig").DEPTH_CY;

const rgb_fx = @import("config.zig").RGB_FX;
const rgb_fy = @import("config.zig").RGB_FY;
const rgb_cx = @import("config.zig").RGB_CX;
const rgb_cy = @import("config.zig").RGB_CY;

const R = [3][3]f64{
    .{ 1.0, 0.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 0.0, 1.0 },
};

const T = [3]f64{ 0.025, 0.0, 0.0 };

pub const Point = struct {
    x: f64,
    y: f64,
    z: f64,
    r: u8,
    g: u8,
    b: u8,
};

pub fn framePairToPointCloud(allocator: std.mem.Allocator, frames: *const FramePair) ![]Point {
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
            if (z_mm == 0) continue;

            const z: f64 = @as(f64, @floatFromInt(z_mm)) / 1000.0; // mm to meters
            const x: f64 = ((@as(f64, @floatFromInt(u)) - depth_cx) * z) / depth_fx;
            const y: f64 = ((@as(f64, @floatFromInt(v)) - depth_cy) * z) / depth_fy;

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
    return points[0..count];
}

pub fn writePLY(points: []const Point, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{}); // fixed
    defer file.close();

    var writer_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&writer_buf);
    const w = &file_writer.interface;

    try w.print(
        "ply\nformat ascii 1.0\nelement vertex {d}\nproperty float x\nproperty float y\nproperty float z\nproperty uchar red\nproperty uchar green\nproperty uchar blue\nend_header\n",
        .{points.len},
    );

    for (points) |p| {
        try w.print(
            "{d:.3} {d:.3} {d:.3} {d} {d} {d}\n",
            .{ p.x, p.y, p.z, p.r, p.g, p.b },
        );
    }
    try w.flush();
}

fn linearToSrgb(c: u8) u8 {
    const f = @as(f64, @floatFromInt(c)) / 255.0;
    const srgb = if (f <= 0.0031308)
        12.92 * f
    else
        1.055 * std.math.pow(f64, f, 1.0 / 2.4) - 0.055;
    return @as(u8, @intFromFloat(std.math.clamp(srgb * 255.0, 0, 255)));
}
