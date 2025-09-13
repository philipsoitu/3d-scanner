const std = @import("std");
const config = @import("config.zig");
const Vec3 = @import("types/math/Vec3.zig").Vec3;
const Mat3x3 = @import("types/math/Mat3x3.zig").Mat3x3;
const Mat4x4 = @import("types/math/Mat4x4.zig").Mat4x4;
const Quaternion = @import("types/math/Quaternion.zig").Quaternion;
const PointCloud = @import("types/PointCloud.zig").PointCloud;
const Point = @import("types/PointCloud.zig").Point;

pub fn run(allocator: std.mem.Allocator) !void {
    const pointclouds = try getPointclouds(allocator, "kinect_output/pointcloud/");
    defer allocator.free(pointclouds);
    std.debug.print("{d} pointclouds found\n", .{pointclouds.len});

    // filename
    var filename_buf: [256]u8 = undefined;
    const filename = try std.fmt.bufPrint(
        &filename_buf,
        "{s}/pointcloud/{d}.ply",
        .{ config.OUTPUT_LOCATION, pointclouds[0] },
    );

    var merged = try PointCloud.open(allocator, filename);
    defer allocator.free(merged.points);

    for (pointclouds[1..]) |p| {
        var other_filename_buf: [256]u8 = undefined;
        const other_filename = try std.fmt.bufPrint(
            &other_filename_buf,
            "{s}/pointcloud/{d}.ply",
            .{ config.OUTPUT_LOCATION, p },
        );

        var next = try PointCloud.open(allocator, other_filename);
        defer allocator.free(next.points);

        try icp_align(&next, &merged, allocator);

        const old = merged.len;
        const new = old + next.len;
        const buf = try allocator.realloc(Point, merged, new);
        std.mem.copy(Point, buf[old..], next);
        allocator.free(next);
        merged = buf;
    }
    try merged.save("final.ply");
    allocator.free(merged);
}

fn estimate_transform(src: *PointCloud, tgt: *PointCloud) !struct { R: Mat3x3, t: Vec3 } {
    const n = src.points.len;

    var center_src: Vec3 = .{ 0, 0, 0 };
    var center_tgt: Vec3 = .{ 0, 0, 0 };

    for (src.points) |ps| {
        const vec_src = Vec3.fromPoint(ps);
        center_src = Vec3.add(&center_src, &vec_src);
    }
    for (tgt.points) |pt| {
        const vec_tgt = Vec3.fromPoint(pt);
        center_tgt = Vec3.add(&center_tgt, &vec_tgt);
    }
    center_src = Vec3.scalar_multiply(center_src, 1.0 / @as(f64, @floatFromInt(n)));
    center_tgt = Vec3.scalar_multiply(center_tgt, 1.0 / @as(f64, @floatFromInt(n)));

    var H: Mat3x3 = .{ .data = .{
        .{ 0, 0, 0 },
        .{ 0, 0, 0 },
        .{ 0, 0, 0 },
    } };
    for (0..n) |i| {
        const src_vec = Vec3.fromPoint(src.points[i]);
        const tgt_vec = Vec3.fromPoint(tgt.points[i]);
        const a = Vec3.sub(&src_vec, center_src);
        const b = Vec3.sub(&tgt_vec, center_src);
        const ab: Mat3x3 = .{ .data = .{
            .{ a.x * b.x, a.x * b.y, a.x * b.z },
            .{ a.y * b.x, a.y * b.y, a.y * b.z },
            .{ a.z * b.x, a.z * b.y, a.z * b.z },
        } };
        H = Mat3x3.add(&H, &ab);
    }

    const N: Mat4x4 = .{ .data = .{
        .{ H.data[0][0] + H.data[1][1] + H.data[2][2], H.data[1][2] - H.data[2][1], H.data[2][0] - H.data[0][2], H.data[0][1] - H.data[1][0] },
        .{ H.data[1][2] - H.data[2][1], H.data[0][0] - H.data[1][1] - H.data[2][2], H.data[0][1] + H.data[1][0], H.data[0][2] + H.data[2][0] },
        .{ H.data[2][0] - H.data[0][2], H.data[0][1] + H.data[1][0], -H.data[0][0] + H.data[1][1] - H.data[2][2], H.data[1][2] + H.data[2][1] },
        .{ H.data[0][1] - H.data[1][0], H.data[0][2] + H.data[2][0], H.data[1][2] + H.data[2][1], -H.data[0][0] - H.data[1][1] + H.data[2][2] },
    } };
    const q = N.power_iter();
    const R = q.toRotationMatrix();
    const rotated = Vec3.apply_rotation(&center_src, R);
    const t = Vec3.sub(&center_tgt, &rotated);
    return .{ .R = R, .t = t };
}

fn transform_points(pointcloud: *PointCloud, R: *Mat3x3, t: *Vec3) void {
    for (pointcloud.points) |*p| {
        const v = Vec3{
            .x = p.x,
            .y = p.y,
            .z = p.z,
        };

        const rv = Vec3.apply_rotation(&v, &R);
        p.x = rv[0] + t[0];
        p.y = rv[1] + t[1];
        p.z = rv[2] + t[2];
    }
}

fn find_corresp(src: *PointCloud, tgt: *PointCloud, allocator: std.mem.Allocator) !struct { srcs: *PointCloud, tgts: *PointCloud } {
    const n = src.points.len;
    var srcs = try allocator.alloc(Point, n);
    var tgts = try allocator.alloc(Point, n);
    for (0..n) |i| {
        const s = src.points[i];
        var best: usize = 0;
        var bestd: f64 = 1e30;
        for (tgt.points, 0..) |tt, j| {
            const dx = s.x - tt.x;
            const dy = s.y - tt.y;
            const dz = s.z - tt.z;
            const d = dx * dx + dy * dy + dz * dz;
            if (d < bestd) {
                bestd = d;
                best = j;
            }
        }
        srcs[i] = Point{
            .x = s.x,
            .y = s.y,
            .z = s.z,
            .r = src.points[i].r,
            .g = src.points[i].g,
            .b = src.points[i].b,
        };

        tgts[i] = Point{
            .x = tgt.points[best].x,
            .y = tgt.points[best].y,
            .z = tgt.points[best].z,
            .r = tgt.points[i].r,
            .g = tgt.points[i].g,
            .b = tgt.points[i].b,
        };
    }
    return .{ .srcs = srcs, .tgts = tgts };
}

fn icp_align(src: *PointCloud, tgt: *PointCloud, allocator: std.mem.Allocator) !void {
    for (0..20) |_| {
        const corresp = try find_corresp(src, tgt, allocator);
        const est = try estimate_transform(corresp.srcs, corresp.tgts, allocator);
        transform_points(src, est.R, est.t);
    }
}

fn getPointclouds(allocator: std.mem.Allocator, path: []const u8) ![]u32 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var list = std.ArrayList(u32){};

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        if (std.mem.endsWith(u8, entry.name, ".ply")) {
            const dot_index = std.mem.lastIndexOfScalar(u8, entry.name, '.') orelse continue;
            const number_str = entry.name[0..dot_index];

            const ts = try std.fmt.parseInt(u32, number_str, 10);
            try list.append(allocator, ts);
        }
    }

    return try list.toOwnedSlice(allocator);
}
