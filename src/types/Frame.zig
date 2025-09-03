const std = @import("std");
const config = @import("../config.zig");

pub const Frame = struct {
    data: []u8,
    timestamp: u32,
    width: usize,
    height: usize,
    type: enum { Rgb, Depth },

    pub fn save(self: *const Frame) !void {
        const prefix = switch (self.type) {
            .Rgb => "rgb",
            .Depth => "depth",
        };
        const ext = switch (self.type) {
            .Rgb => "ppm",
            .Depth => "pgm",
        };

        var filename_buf: [128]u8 = undefined;

        const filename = try std.fmt.bufPrint(
            &filename_buf,
            "{s}/{s}/{d}.{s}",
            .{ config.OUTPUT_LOCATION, prefix, self.timestamp, ext },
        );

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
                "P5\n{d} {d}\n65535\n",
                .{ self.*.width, self.*.height },
            ),
        }
        // raw binary data
        if (self.type == .Depth) {
            // flip endianness
            for (0..self.width * self.height) |i| {
                const lo = self.data[i * 2];
                const hi = self.data[i * 2 + 1];
                const be_bytes = [_]u8{ hi, lo };
                try w.writeAll(&be_bytes);
            }
        } else if (self.type == .Rgb) {
            try w.writeAll(self.data);
        }

        //cleanup
        try w.flush();

        std.debug.print("saved file: {s}\n", .{filename});
    }
};
