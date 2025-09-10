const std = @import("std");
const config = @import("../config.zig");
const KinectFrame = @import("KinectFrame.zig").KinectFrame;

pub const Frame = union(enum) {
    depth: DepthFrame,
    rgb: RgbFrame,

    pub fn fromKinectFrame(kinect_frame: *const KinectFrame, allocator: std.mem.Allocator) !Frame {
        switch (kinect_frame.type) {
            .rgb => {
                return @This(){
                    .rgb = .{
                        .width = kinect_frame.width,
                        .height = kinect_frame.height,
                        .timestamp = kinect_frame.timestamp,
                        .data = @constCast(kinect_frame.data),
                    },
                };
            },
            .depth => {
                const num_pixels = kinect_frame.width * kinect_frame.height;
                var buf = try allocator.alloc(u16, num_pixels);

                // reinterpret Kinect bytes as u16 slice
                const raw_u16 = std.mem.bytesAsSlice(u16, kinect_frame.data);

                for (0..buf.len) |i| {
                    buf[i] = @as(u16, @byteSwap(raw_u16[i]));
                }
                return @This(){
                    .depth = .{
                        .width = kinect_frame.width,
                        .height = kinect_frame.height,
                        .timestamp = kinect_frame.timestamp,
                        .data = buf,
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
