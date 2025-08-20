const std = @import("std");
const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

const Frame = struct {
    rgb: []u8,
    depth: []u16,
    width: usize,
    height: usize,
};

var got_rgb = false;
var got_depth = false;
var rgb_buf: []u8 = &[_]u8{};
var depth_buf: []u16 = &[_]u16{};

fn video_cb(dev: ?*c.freenect_device, video: ?*anyopaque, timestamp: u32) callconv(.C) void {
    _ = dev;
    _ = timestamp;
    if (video) |v| {
        const raw = @as([*]u8, @ptrCast(v))[0 .. 640 * 480 * 3];
        rgb_buf = raw; // shallow reference, we’ll copy later if needed
        got_rgb = true;
    }
}

fn depth_cb(dev: ?*c.freenect_device, depth: ?*anyopaque, timestamp: u32) callconv(.C) void {
    _ = dev;
    _ = timestamp;
    if (depth) |d| {
        const raw = @as([*]u16, @alignCast(@ptrCast(d)))[0 .. 640 * 480];
        depth_buf = raw;
        got_depth = true;
    }
}

fn capture_frame(ctx: *c.freenect_context, dev: *c.freenect_device) !Frame {
    got_rgb = false;
    got_depth = false;

    c.freenect_set_video_callback(dev, video_cb);
    c.freenect_set_depth_callback(dev, depth_cb);

    if (c.freenect_start_video(dev) != 0) return error.VideoStartFailed;
    if (c.freenect_start_depth(dev) != 0) return error.DepthStartFailed;

    // Run event loop until we get both frames
    while (!(got_rgb and got_depth)) {
        if (c.freenect_process_events(ctx) < 0) return error.EventLoopFailed;
    }

    _ = c.freenect_stop_video(dev);
    _ = c.freenect_stop_depth(dev);

    return Frame{
        .rgb = rgb_buf,
        .depth = depth_buf,
        .width = 640,
        .height = 480,
    };
}

fn save_rgb_ppm(frame: Frame, filename: []const u8) !void {
    var file = try std.fs.cwd().createFile(filename, .{}); // fixed
    defer file.close();

    try file.writer().print("P6\n{d} {d}\n255\n", .{ frame.width, frame.height });
    try file.writeAll(frame.rgb);
}

fn save_depth_pgm(frame: Frame, filename: []const u8) !void {
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

pub fn main() !void {
    var ctx: ?*c.freenect_context = null;
    if (c.freenect_init(&ctx, null) < 0) {
        std.debug.print("freenect init failed\n", .{});
        return;
    }
    defer _ = c.freenect_shutdown(ctx);

    const num_devices = c.freenect_num_devices(ctx);
    std.debug.print("num_devices: {d}\n", .{num_devices});

    if (num_devices > 0) {
        var dev: ?*c.freenect_device = null;
        if (c.freenect_open_device(ctx, &dev, 0) == 0) {
            const frame = try capture_frame(ctx.?, dev.?);
            std.debug.print("Captured frame {d}x{d}\n", .{ frame.width, frame.height });

            try save_rgb_ppm(frame, "rgb.ppm");
            try save_depth_pgm(frame, "depth.pgm");

            std.debug.print("Saved rgb.ppm and depth.pgm\n", .{});
            _ = c.freenect_close_device(dev);
        }
    }
}
