const std = @import("std");
const kinect = @import("kinect.zig");
const consumer = @import("consumer.zig");
const config = @import("config.zig");
const cli = @import("cli.zig");

const Queue = @import("types/Queue.zig").Queue;
const BufferPool = @import("types/BufferPool.zig").BufferPool;
const Frame = @import("types/Frame.zig").Frame;

pub fn run(allocator: std.mem.Allocator) !void {
    var rgb_pool = try BufferPool.init(allocator, config.POOL_SIZE, config.RGB_BUFFER_SIZE);
    defer rgb_pool.deinit();
    var depth_pool = try BufferPool.init(allocator, config.POOL_SIZE, config.DEPTH_BUFFER_SIZE);
    defer depth_pool.deinit();

    var rgb_queue = Queue.init(allocator);
    defer rgb_queue.deinit();
    var depth_queue = Queue.init(allocator);
    defer depth_queue.deinit();

    var rgb_thread = try std.Thread.spawn(
        .{},
        consumer.thread,
        .{ &rgb_queue, &rgb_pool },
    );
    var depth_thread = try std.Thread.spawn(
        .{},
        consumer.thread,
        .{ &depth_queue, &depth_pool },
    );

    var kinect_ctx = kinect.KinectCtx{
        .rgb_queue = &rgb_queue,
        .rgb_pool = &rgb_pool,
        .rgb_index = 0,
        .depth_queue = &depth_queue,
        .depth_pool = &depth_pool,
        .depth_index = 0,
    };

    var k = try kinect.Kinect.init(&kinect_ctx);

    // small delay to let the kinect start up
    std.debug.print("starting kinect, main loop will run in 5 seconds\n", .{});
    std.Thread.sleep(std.time.ns_per_s);
    for (0..5) |i| {
        std.debug.print("{}\n", .{5 - i - 1});
        std.Thread.sleep(std.time.ns_per_s);
    }
    std.debug.print("running main loop\n", .{});

    try k.runLoop();
    defer k.shutdown();

    rgb_queue.finish();
    depth_queue.finish();

    rgb_thread.join();
    depth_thread.join();
}
