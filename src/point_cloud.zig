const std = @import("std");
const Frame = @import("frame.zig").Frame;

const depth_fx: f64 = 594.21;
const depth_fy: f64 = 591.04;
const depth_cx: f64 = 339.5;
const depth_cy: f64 = 242.7;

const rgb_fx: f64 = 529.2;
const rgb_fy: f64 = 525.6;
const rgb_cx: f64 = 329.0;
const rgb_cy: f64 = 247.6;

pub const Point = struct {
    x: f64,
    y: f64,
    z: f64,
    r: u8,
    g: u8,
    b: u8,
};

pub fn frameToPoints(allocator: std.mem.Allocator, frame: *Frame) ![]Point {
    var points = try allocator.alloc(Point, frame.height * frame.width);
    var count: usize = 0;

    for (0..frame.height) |v| {
        for (0..frame.width) |u| {
            const idx = v * frame.width + u;

            const z_mm = frame.depth[idx];
            if (z_mm == 0) continue;

            const z: f64 = @as(f64, @floatFromInt(z_mm)) / 1000.0; // mm to meters
            const x: f64 = ((@as(f64, @floatFromInt(u)) - depth_cx) * z) / depth_fx;
            const y: f64 = ((@as(f64, @floatFromInt(v)) - depth_cy) * z) / depth_fy;

            const rgb_idx = idx * 3;
            const r: u8 = frame.rgb[rgb_idx + 0];
            const g: u8 = frame.rgb[rgb_idx + 1];
            const b: u8 = frame.rgb[rgb_idx + 2];

            points[count] = Point{
                .x = x,
                .y = y,
                .z = z,
                .r = r,
                .g = g,
                .b = b,
            };
            count += 1;
        }
    }
    return points[0..count];
}

pub fn writePLY(points: []const Point, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{}); // fixed
    defer file.close();

    try file.writer().print(
        "ply\nformat ascii 1.0\nelement vertex {d}\nproperty float x\nproperty float y\nproperty float z\nproperty uchar red\nproperty uchar green\nproperty uchar blue\nend_header\n",
        .{points.len},
    );

    for (points) |p| {
        try file.writer().print("{d:.3} {d:.3} {d:.3} {d} {d} {d}\n", .{ p.x, p.y, p.z, p.r, p.g, p.b });
    }
}
