const std = @import("std");
const Frame = @import("frame.zig").Frame;
const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
});

const c_void = extern struct {};

pub const KinectState = struct {
    depth_captured: bool,
    rgb_captured: bool,
    frame: *Frame,
};

pub const Kinect = struct {
    ctx: ?*c.freenect_context,
    dev: ?*c.freenect_device,

    rgb_buffer: [640 * 480 * 3]u8,
    depth_buffer: [640 * 480]u16,

    pub fn init(starting_state: ?*KinectState) !Kinect {
        var k = Kinect{
            .ctx = null,
            .dev = null,
            .rgb_buffer = std.mem.zeroes([640 * 480 * 3]u8),
            .depth_buffer = std.mem.zeroes([640 * 480]u16),
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

        c.freenect_set_user(k.dev, @as(?*anyopaque, @ptrCast(starting_state)));

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
            const raw_ptr = c.freenect_get_user(self.dev);
            const state_ptr = @as(?*KinectState, @ptrCast(@alignCast(raw_ptr)));

            if (state_ptr) |p| {
                if (p.depth_captured and p.rgb_captured) {
                    return;
                }
            }

            const result = c.freenect_process_events(self.ctx);
            if (result < 0) {
                return error.EventLoopFailed;
            }
        }
    }

    pub fn shutdown(self: *Kinect) void {
        _ = c.freenect_stop_depth(self.dev);
        _ = c.freenect_stop_video(self.dev);

        // flush usb
        _ = c.freenect_process_events(self.ctx);
        _ = c.freenect_process_events(self.ctx);
        _ = c.freenect_process_events(self.ctx);

        // small delay
        std.time.sleep(100 * std.time.ns_per_ms);

        _ = c.freenect_close_device(self.dev);
        _ = c.freenect_shutdown(self.ctx);
    }
};

// ----- CALLBACKS -----
fn depthCb(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.C) void {
    _ = .{timestamp};
    const raw_ptr = c.freenect_get_user(dev);
    const state_ptr = @as(?*KinectState, @ptrCast(@alignCast(raw_ptr)));

    if (state_ptr) |p| {
        if (!p.depth_captured) {
            if (data) |raw| {
                const depth_ptr = @as([*]u16, @ptrCast(@alignCast(raw)));
                const depth_slice = depth_ptr[0 .. 640 * 480];

                p.frame.depth = depth_slice;
                p.depth_captured = true;
            }
        }
    }
}

fn videoCb(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.C) void {
    _ = .{timestamp};
    const raw_ptr = c.freenect_get_user(dev);
    const state_ptr = @as(?*KinectState, @ptrCast(@alignCast(raw_ptr)));

    if (state_ptr) |p| {
        if (!p.rgb_captured) {
            if (data) |raw| {
                const rgb_ptr = @as([*]u8, @ptrCast(@alignCast(raw)));
                const rgb_slice = rgb_ptr[0 .. 640 * 480 * 3];

                p.frame.rgb = rgb_slice;
                p.rgb_captured = true;
            }
        }
    }
}
