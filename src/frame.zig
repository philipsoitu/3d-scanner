const std = @import("std");

pub const Frame = struct {
    rgb: []u8,
    depth: []u16,
    width: usize,
    height: usize,

    pub fn init(width: usize, height: usize) Frame {
        return Frame{
            .rgb = &[_]u8{},
            .depth = &[_]u16{},
            .width = width,
            .height = height,
        };
    }

    pub fn save_rgb_ppm(self: *Frame, filename: []const u8) !void {
        var file = try std.fs.cwd().createFile(filename, .{}); // fixed
        defer file.close();

        try file.writer().print("P6\n{d} {d}\n255\n", .{ self.*.width, self.*.height });
        try file.writeAll(self.*.rgb);
    }

    pub fn save_depth_pgm(self: *Frame, filename: []const u8) !void {
        var file = try std.fs.cwd().createFile(filename, .{}); // fixed
        defer file.close();

        try file.writer().print("P5\n{d} {d}\n2047\n", .{ self.*.width, self.*.height });

        var buf: [2]u8 = undefined;
        for (self.*.depth) |d| {
            buf[0] = @as(u8, @intCast(d >> 8)); // high byte
            buf[1] = @as(u8, @intCast(d & 0xFF)); // low byte
            try file.writeAll(&buf);
        }
    }
};
