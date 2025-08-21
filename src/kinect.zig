const std = @import("std");
const Frame = @import("frame.zig").Frame;
const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

const c_void = extern struct {};

pub const Kinect = struct {
    ctx: ?*c.freenect_context,
    dev: ?*c.freenect_device,

    rgb_buffer: [640 * 480 * 3]u8,
    depth_buffer: [640 * 480]u11,

    pub fn init() !Kinect {
        var k = Kinect{
            .ctx = null,
            .dev = null,
            .rgb_buffer = std.mem.zeroes([640 * 480 * 3]u8),
            .depth_buffer = std.mem.zeroes([640 * 480]u11),
        };

        // init context
        if (c.freenect_init(&k.ctx, null) < 0) {
            return error.InitFailed;
        }

        // set logs
        c.freenect_set_log_level(k.ctx, c.FREENECT_LOG_DEBUG);
        c.freenect_select_subdevices(k.ctx, c.FREENECT_DEVICE_CAMERA);

        // get num of device
        const num_devices = c.freenect_num_devices(k.ctx);
        if (num_devices == 0) {
            _ = c.freenect_shutdown(k.ctx);
            return error.NoDevice;
        }

        // connect to device
        if (c.freenect_open_device(k.ctx, &k.dev, 0) != 0) {
            _ = c.freenect_shutdown(k.ctx);
            return error.DeviceOpenFailed;
        }

        // set modes
        _ = c.freenect_set_depth_mode(k.dev, c.freenect_find_depth_mode(
            c.FREENECT_RESOLUTION_MEDIUM,
            c.FREENECT_DEPTH_MM,
        ));
        _ = c.freenect_set_video_mode(k.dev, c.freenect_find_video_mode(
            c.FREENECT_RESOLUTION_MEDIUM,
            c.FREENECT_VIDEO_RGB,
        ));

        // set callbacks
        c.freenect_set_depth_callback(k.dev, depthCb);
        c.freenect_set_video_callback(k.dev, videoCb);

        // start streams
        _ = c.freenect_start_depth(k.dev);
        _ = c.freenect_start_video(k.dev);

        return k;
    }

    pub fn runLoop(self: *Kinect) !void {
        while (true) {
            const result = c.freenect_process_events(self.ctx);
            if (result < 0) {
                return error.EventLoopFailed;
            }
        }
    }

    pub fn shutdown(self: *Kinect) void {
        _ = c.freenect_stop_depth(self.dev);
        _ = c.freenect_stop_video(self.dev);
        _ = c.freenect_close_device(self.dev);
        _ = c.freenect_shutdown(self.ctx);
    }
};
// ----- CALLBAKCS -----
fn depthCb(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.C) void {
    _ = .{dev};
    if (data) |raw| {
        const depth_ptr = @as([*]u16, @ptrCast(@alignCast(raw)));
        const depth_slice = depth_ptr[0 .. 640 * 480];

        var frame = Frame{
            .rgb = &[_]u8{},
            .depth = depth_slice,
            .width = 640,
            .height = 480,
        };

        const filename = std.fmt.allocPrint(std.heap.c_allocator, "kinect_output/depth/{d}.pgm", .{timestamp}) catch return;
        defer std.heap.c_allocator.free(filename);

        frame.save_depth_pgm(filename) catch |err| {
            std.debug.print("Failed to save depth frame: {}\n", .{err});
        };
    }
    std.debug.print("Received depth frame at {d}\n", .{timestamp});
}

fn videoCb(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.C) void {
    _ = .{dev};
    if (data) |raw| {
        const rgb_ptr = @as([*]u8, @ptrCast(@alignCast(raw)));
        const rgb_slice = rgb_ptr[0 .. 640 * 480 * 3];

        var frame = Frame{
            .rgb = rgb_slice,
            .depth = &[_]u16{},
            .width = 640,
            .height = 480,
        };

        const filename = std.fmt.allocPrint(std.heap.c_allocator, "kinect_output/rgb/{d}.ppm", .{timestamp}) catch return;
        defer std.heap.c_allocator.free(filename);

        frame.save_rgb_ppm(filename) catch |err| {
            std.debug.print("Failed to save rgb frame: {}\n", .{err});
        };
    }
    std.debug.print("Received rgb frame at {d}\n", .{timestamp});
}
