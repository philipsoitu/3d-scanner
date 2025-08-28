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

const R = [3][3]f64{
    .{ 1.0, 0.0, 0.0 },
    .{ 0.0, 1.0, 0.0 },
    .{ 0.0, 0.0, 1.0 },
};
const T = [3]f64{ 0.020, 0.0, 0.0 }; // ~2.5 cm baseline

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

            const pd = [3]f64{ x, y, z };

            // P_rgb = R * P_d + T or whatever
            var prgb: [3]f64 = undefined;
            for (0..3) |row| {
                prgb[row] = R[row][0] * pd[0] + R[row][1] * pd[1] + R[row][2] * pd[2] + T[row];
            }

            if (prgb[2] <= 0.0) continue; //behind rgb camera

            const u_rgb = @as(isize, @intFromFloat(rgb_fx * prgb[0] / prgb[2] + rgb_cx));
            const v_rgb = @as(isize, @intFromFloat(rgb_fx * prgb[1] / prgb[2] + rgb_cy));

            // 4. Check bounds
            if (u_rgb < 0 or u_rgb >= @as(isize, @intCast(frame.width))) continue;
            if (v_rgb < 0 or v_rgb >= @as(isize, @intCast(frame.height))) continue;

            const rgb_idx = (@as(usize, @intCast(v_rgb)) * frame.width + @as(usize, @intCast(u_rgb))) * 3;
            const r: u8 = frame.rgb[rgb_idx + 0];
            const g: u8 = frame.rgb[rgb_idx + 1];
            const b: u8 = frame.rgb[rgb_idx + 2];

            points[count] = Point{
                .x = pd[0],
                .y = -pd[1],
                .z = -pd[2],
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
