const std = @import("std");
const Frame = @import("frame.zig").Frame;

pub fn save_rgb_ppm(frame: Frame, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{}); // fixed
    defer file.close();

    try file.writer().print("P6\n{d} {d}\n255\n", .{ frame.width, frame.height });
    try file.writeAll(frame.rgb);
}

pub fn save_depth_pgm(frame: Frame, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{}); // fixed
    defer file.close();

    try file.writer().print("P5\n{d} {d}\n2047\n", .{ frame.width, frame.height });

    var buf: [2]u8 = undefined;
    for (frame.depth) |d| {
        buf[0] = @as(u8, @intCast(d >> 8)); // high byte
        buf[1] = @as(u8, @intCast(d & 0xFF)); // low byte
        try file.writeAll(&buf);
    }
}
