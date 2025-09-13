const std = @import("std");

// ----------------- File collection -----------------

fn collect_files(allocator: *std.mem.Allocator) ![]struct { ts: u32, path: []const u8 } {
    var dir = try std.fs.cwd().openDir("kinect_output/pointcloud", .{ .iterate = true });
    defer dir.close();
    var list = std.ArrayList(struct { ts: u32, path: []const u8 }).init(allocator);
    var it = dir.iterate();
    while (try it.next()) |ent| {
        if (ent.kind != .file) continue;
        if (!std.mem.endsWith(u8, ent.name, ".ply")) continue;
        const stem = ent.name[0 .. ent.name.len - 4];
        const ts = std.fmt.parseInt(u32, stem, 10) catch continue;
        const full = try std.fs.path.join(allocator, &.{ "kinect_output/pointcloud", ent.name });
        try list.append(.{ .ts = ts, .path = full });
    }
    var arr = try list.toOwnedSlice();
    std.sort.sort(struct { ts: u32, path: []const u8 }, arr, {}, struct {
        fn lt(_: void, a: @This(), b: @This()) bool {
            return a.ts < b.ts;
        }
    }.lt);
    return arr;
}

// ----------------- Main -----------------

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const A = &gpa.allocator;

    const files = try collect_files(A);
    if (files.len == 0) {
        std.debug.print("No .ply found\n", .{});
        return;
    }

    var merged = try load_ply_ascii(files[0].path, A);
    for (files[1..]) |f| {
        var next = try load_ply_ascii(f.path, A);
        try icp_align(next, merged, A);
        const old = merged.len;
        const new = old + next.len;
        const buf = try A.realloc(Point3D, merged, new);
        std.mem.copy(Point3D, buf[old..], next);
        A.free(next);
        merged = buf;
    }
    try save_ply_ascii("merged_scene.ply", merged);
    A.free(merged);
    for (files) |f| A.free(f.path);
    A.free(files);
}
