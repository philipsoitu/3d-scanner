const std = @import("std");

pub const FrameType = enum { Rgb, Depth };

pub const Frame = struct {
    data: []u8,
    timestamp: u32,
    width: usize,
    height: usize,
    type: FrameType,

    pub fn save(self: *const Frame, allocator: std.mem.Allocator) !void {
        const file_ending = switch (self.type) {
            .Rgb => "ppm",
            .Depth => "pgm",
        };
        const filename = try std.fmt.allocPrint(
            allocator,
            "kinect_output/{d}.{s}",
            .{ self.timestamp, file_ending },
        );
        defer allocator.free(filename);

        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        var buf: [4096]u8 = undefined;
        var file_writer = file.writer(&buf);
        const w = &file_writer.interface;

        // Header
        switch (self.type) {
            .Rgb => try w.print(
                "P6\n{d} {d}\n255\n",
                .{ self.width, self.height },
            ),
            .Depth => try w.print(
                "P5\n{d} {d}\n65536\n",
                .{ self.*.width, self.*.height },
            ),
        }
        // raw binary data
        try w.writeAll(self.data);

        try w.flush();
    }
};
