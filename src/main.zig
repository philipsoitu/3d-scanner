const std = @import("std");
const kinect = @import("kinect.zig");
const point_cloud = @import("point_cloud.zig");
const consumer = @import("consumer.zig");
const config = @import("config.zig");
const cli = @import("cli.zig");

const capture = @import("capture.zig").run;
const generate = @import("generate.zig").run;

const Queue = @import("types/Queue.zig").Queue;
const BufferPool = @import("types/BufferPool.zig").BufferPool;
const Frame = @import("types/Frame.zig").Frame;

const commands = [_]cli.Command{
    .{ .name = "capture", .handler = capture },
    .{ .name = "generate", .handler = generate },
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try cli.parseArgs(allocator, args, &commands);
}
