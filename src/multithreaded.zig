const std = @import("std");
const Queue = @import("Queue.zig").Queue;
const BufferPool = @import("BufferPool.zig").BufferPool;
const Frame = @import("frame.zig").Frame;
const FrameType = @import("frame.zig").FrameType;

pub const ConsumerCtx = struct {
    queue: *Queue,
    pool: *BufferPool,
    prefix: []const u8,
    frame_type: FrameType,
};

pub fn consumerThread(ctx: *ConsumerCtx) !void {
    while (true) {
        const maybe_frame = ctx.queue.pop();
        if (maybe_frame == null) break;

        const frame = maybe_frame.?;
        try frame.save();

        ctx.pool.release(frame.data);
    }
}
