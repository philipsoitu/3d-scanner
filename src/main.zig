const std = @import("std");
const kinect = @import("kinect.zig");
const point_cloud = @import("point_cloud.zig");
const multithreaded = @import("multithreaded.zig");
const config = @import("config.zig");

const Queue = @import("Queue.zig").Queue;
const BufferPool = @import("BufferPool.zig").BufferPool;
const Frame = @import("frame.zig").Frame;
const FrameType = @import("frame.zig").FrameType;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var rgb_pool = try BufferPool.init(
        allocator,
        config.POOL_SIZE,
        config.WIDTH * config.HEIGHT * config.RGB_BYTES,
    );
    defer rgb_pool.deinit();

    var depth_pool = try BufferPool.init(
        allocator,
        config.POOL_SIZE,
        config.WIDTH * config.HEIGHT * config.DEPTH_BYTES,
    );
    defer depth_pool.deinit();

    var rgb_queue = Queue.init(allocator);
    defer rgb_queue.deinit();
    var depth_queue = Queue.init(allocator);
    defer depth_queue.deinit();

    var rgb_ctx = multithreaded.ConsumerCtx{ .queue = &rgb_queue, .pool = &rgb_pool, .prefix = "rgb", .frame_type = .Rgb };
    var depth_ctx = multithreaded.ConsumerCtx{ .queue = &depth_queue, .pool = &depth_pool, .prefix = "depth", .frame_type = .Depth };

    var rgb_consumer = try std.Thread.spawn(.{}, multithreaded.consumerThread, .{&rgb_ctx});
    var depth_consumer = try std.Thread.spawn(.{}, multithreaded.consumerThread, .{&depth_ctx});

    var kinect_ctx = kinect.KinectCtx{
        .rgb_queue = &rgb_queue,
        .rgb_pool = &rgb_pool,
        .rgb_index = 0,
        .depth_queue = &depth_queue,
        .depth_pool = &depth_pool,
        .depth_index = 0,
    };

    var k = try kinect.Kinect.init(&kinect_ctx);
    try k.runLoop();
    defer k.shutdown();

    // Signal consumers and wait
    rgb_queue.finish();
    depth_queue.finish();

    rgb_consumer.join();
    depth_consumer.join();
}
