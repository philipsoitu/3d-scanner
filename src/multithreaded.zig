const std = @import("std");
const Queue = @import("Queue.zig").Queue;
const BufferPool = @import("BufferPool.zig").BufferPool;
const Frame = @import("frame.zig").Frame;
const FrameType = @import("frame.zig").FrameType;

pub fn consumerThread(
    queue: *Queue,
    pool: *BufferPool,
) !void {
    while (true) {
        const maybe_frame = queue.pop();
        if (maybe_frame == null) break;

        const frame = maybe_frame.?;
        try frame.save();

        pool.release(frame.data);
    }
}
