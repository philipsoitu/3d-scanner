const std = @import("std");
const Frame = @import("types/Frame.zig").Frame;
const FramePair = @import("types/FramePair.zig").FramePair;

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
const T = [3]f64{ 0.020, 0.0, 0.0 }; // ~2.5 cm distance between cameras

pub const Point = struct {
    x: f64,
    y: f64,
    z: f64,
    r: u8,
    g: u8,
    b: u8,
};

pub fn framesToPointCloud(allocator: std.mem.Allocator, frames: *const FramePair) ![]Point {
    const depth_frame = try frames.getDepthFrame(allocator);
    defer allocator.free(depth_frame.data);

    const rgb_frame = try frames.getRgbFrame(allocator);
    defer allocator.free(rgb_frame.data);

    const num_points = depth_frame.width * depth_frame.height;
    var points = try allocator.alloc(Point, num_points);
    var idx: usize = 0;

    for (0..num_points) |pix| {
        const i = pix * 2;

        // big endian depth
        const d: u16 = (@as(u16, depth_frame.data[i]) << 8) | @as(u16, depth_frame.data[i + 1]);
        if (d == 0) continue;

        const u = pix % depth_frame.width;
        const v = pix / depth_frame.width;

        const z = @as(f64, @floatFromInt(d)) / 1000.0; // mm to meters
        const x: f64 = ((@as(f64, @floatFromInt(u)) - depth_cx) * z) / depth_fx;
        const y: f64 = ((@as(f64, @floatFromInt(v)) - depth_cy) * z) / depth_fy;

        const Xd = x;
        const Yd = y;
        const Zd = z;

        const Xr = R[0][0] * Xd + R[0][1] * Yd + R[0][2] * Zd + T[0];
        const Yr = R[1][0] * Xd + R[1][1] * Yd + R[1][2] * Zd + T[1];
        const Zr = R[2][0] * Xd + R[2][1] * Yd + R[2][2] * Zd + T[2];

        const u_rgb = @as(isize, @intFromFloat((Xr * rgb_fx) / Zr + rgb_cx));
        const v_rgb = @as(isize, @intFromFloat((Yr * rgb_fy) / Zr + rgb_cy));

        var r: u8 = 0;
        var g: u8 = 0;
        var b: u8 = 0;

        if (u_rgb >= 0 and u_rgb < @as(isize, @intCast(rgb_frame.width)) and
            v_rgb >= 0 and v_rgb < @as(isize, @intCast(rgb_frame.height)))
        {
            const rgb_index: usize = @as(usize, @intCast(v_rgb)) * rgb_frame.width * 3 + @as(usize, @intCast(u_rgb)) * 3;
            r = rgb_frame.data[rgb_index + 0];
            g = rgb_frame.data[rgb_index + 1];
            b = rgb_frame.data[rgb_index + 2];
        }
        points[idx] = Point{
            .x = Xd,
            .y = Yd,
            .z = Zd,
            .r = r,
            .g = g,
            .b = b,
        };
        idx += 1;
    }

    return try allocator.realloc(points, idx);
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
