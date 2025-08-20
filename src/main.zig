const std = @import("std");

const c = @cImport({
    @cInclude("libfreenect/libfreenect.h");
    @cInclude("signal.h");
});

var running: bool = true;

/// Depth callback
fn depthCb(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.C) void {
    _ = .{ dev, data };
    std.debug.print("Received depth frame at {d}\n", .{timestamp});
}

/// Video callback
fn videoCb(dev: ?*c.freenect_device, data: ?*anyopaque, timestamp: u32) callconv(.C) void {
    _ = .{ dev, data };
    std.debug.print("Received video frame at {d}\n", .{timestamp});
}

/// Signal handler to stop loop
fn signalHandler(sig: c_int) callconv(.C) void {
    if (sig == c.SIGINT or sig == c.SIGTERM or sig == c.SIGQUIT) {
        running = false;
    }
}

pub fn main() !void {
    //const allocator = std.heap.page_allocator;

    // install signal handlers
    _ = c.signal(c.SIGINT, signalHandler);
    _ = c.signal(c.SIGTERM, signalHandler);
    _ = c.signal(c.SIGQUIT, signalHandler);

    // init context
    var ctx: ?*c.freenect_context = null;
    _ = try check(c.freenect_init(&ctx, null), "freenect_init");
    defer _ = c.freenect_shutdown(ctx);

    c.freenect_set_log_level(ctx, c.FREENECT_LOG_DEBUG);
    c.freenect_select_subdevices(ctx, c.FREENECT_DEVICE_CAMERA);

    const num = try check(c.freenect_num_devices(ctx), "freenect_num_devices");
    if (num == 0) {
        std.debug.print("No Kinect device found\n", .{});
        return;
    }

    // open device
    var dev: ?*c.freenect_device = null;
    _ = try check(c.freenect_open_device(ctx, &dev, 0), "freenect_open_device");
    defer _ = c.freenect_close_device(dev);

    // set modes
    _ = try check(
        c.freenect_set_depth_mode(dev, c.freenect_find_depth_mode(c.FREENECT_RESOLUTION_MEDIUM, c.FREENECT_DEPTH_MM)),
        "freenect_set_depth_mode",
    );
    _ = try check(
        c.freenect_set_video_mode(dev, c.freenect_find_video_mode(c.FREENECT_RESOLUTION_MEDIUM, c.FREENECT_VIDEO_RGB)),
        "freenect_set_video_mode",
    );

    // set callbacks
    c.freenect_set_depth_callback(dev, depthCb);
    c.freenect_set_video_callback(dev, videoCb);

    // start streams
    _ = try check(c.freenect_start_depth(dev), "freenect_start_depth");
    defer _ = c.freenect_stop_depth(dev);

    _ = try check(c.freenect_start_video(dev), "freenect_start_video");
    defer _ = c.freenect_stop_video(dev);

    // main loop
    while (running) {
        const r = c.freenect_process_events(ctx);
        if (r < 0) break;
    }

    std.debug.print("Shutting down\n", .{});
    std.debug.print("Done!\n", .{});
}

/// Helper: turn libfreenect return codes into Zig errors
fn check(ret: c_int, name: []const u8) !c_int {
    if (ret < 0) {
        std.debug.print("{s} failed: {d}\n", .{ name, ret });
        return error.FreenectError;
    }
    return ret;
}

pub const err = struct {
    FreenectError: error{FreenectError} = error.FreenectError,
};
