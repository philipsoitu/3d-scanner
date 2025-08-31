const std = @import("std");
const Queue = @import("types/Queue.zig").Queue;
const BufferPool = @import("types/BufferPool.zig").BufferPool;
const Frame = @import("types/Frame.zig").Frame;

pub fn thread(
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
