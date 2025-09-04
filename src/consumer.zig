const std = @import("std");

const Frame = @import("types/Frame.zig").Frame;
const Queue = @import("types/Queue.zig").Queue;
const BufferPool = @import("types/BufferPool.zig").BufferPool;

pub fn thread(queue: *Queue, pool: *BufferPool, allocator: std.mem.Allocator) !void {
    while (true) {
        const maybe_kinect_frame = queue.pop();
        if (maybe_kinect_frame) |kinect_frame| {
            const frame = try Frame.fromKinectFrame(&kinect_frame, allocator);
            try frame.save();
            switch (frame) {
                .depth => allocator.free(frame.depth.data),
                else => {},
            }

            pool.release(@constCast(kinect_frame.data));
        }
    }
}
