const std = @import("std");
const config = @import("../config.zig");
const KinectFrame = @import("KinectFrame.zig").KinectFrame;

pub const Frame = union(enum) {
    depth: DepthFrame,
    rgb: RgbFrame,

    pub fn fromKinectFrame(kinect_frame: *const KinectFrame) !Frame {
        switch (kinect_frame.type) {
            .rgb => {
                return @This(){
                    .rgb = .{
                        .width = kinect_frame.width,
                        .height = kinect_frame.height,
                        .timestamp = kinect_frame.timestamp,
                        .data = kinect_frame.data,
                    },
                };
            },
            .depth => {
                var buf: [config.DEPTH_BUFFER_SIZE_U16]u16 = undefined;
                const depth_data = try u8ToU16Swapped(kinect_frame.data, buf[0..]);
                return @This(){
                    .depth = .{
                        .width = kinect_frame.width,
                        .height = kinect_frame.height,
                        .timestamp = kinect_frame.timestamp,
                        .data = depth_data,
                    },
                };
            },
        }
    }

    pub fn save(self: *const @This()) !void {
        switch (self.*) {
            .rgb => try RgbFrame.save(&self.rgb),
            .depth => try DepthFrame.save(&self.depth),
        }
    }
};

pub const DepthFrame = struct {
    width: usize,
    height: usize,
    timestamp: u32,
    data: []u16,

    pub fn save(self: *const DepthFrame) !void {
        var filename_buf: [128]u8 = undefined;

        const filename = try std.fmt.bufPrint(
            &filename_buf,
            "{s}/depth/{d}.pgm",
            .{ config.OUTPUT_LOCATION, self.timestamp },
        );

        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        var buf: [4096]u8 = undefined;
        var file_writer = file.writer(&buf);
        const w = &file_writer.interface;

        // Header
        try w.print(
            "P5\n{d} {d}\n2047\n",
            .{ self.*.width, self.*.height },
        );
        // raw binary data
        try w.writeAll(std.mem.sliceAsBytes(self.data));

        //cleanup
        try w.flush();

        std.debug.print("saved file: {s}\n", .{filename});
    }
};

pub const RgbFrame = struct {
    width: usize,
    height: usize,
    timestamp: u32,
    data: []u8,

    pub fn save(self: *const RgbFrame) !void {
        var filename_buf: [128]u8 = undefined;

        const filename = try std.fmt.bufPrint(
            &filename_buf,
            "{s}/rgb/{d}.ppm",
            .{ config.OUTPUT_LOCATION, self.timestamp },
        );

        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        var buf: [4096]u8 = undefined;
        var file_writer = file.writer(&buf);
        const w = &file_writer.interface;

        try w.print(
            "P6\n{d} {d}\n255\n",
            .{ self.width, self.height },
        );

        try w.writeAll(self.data);

        //cleanup
        try w.flush();

        std.debug.print("saved file: {s}\n", .{filename});
    }
};

pub fn u8ToU16Swapped(bytes: []const u8, out: []u16) ![]u16 {
    if (bytes.len % 2 != 0) return error.InvalidLength;
    if (out.len < bytes.len / 2) return error.BufferTooSmall;

    const count = bytes.len / 2;

    for (0..count) |i| {
        const lo = bytes[i * 2];
        const hi = bytes[i * 2 + 1];
        out[i] = (@as(u16, hi) << 8) | lo;
    }

    return out[0..count];
}
