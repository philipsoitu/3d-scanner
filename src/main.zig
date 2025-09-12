const std = @import("std");
const cli = @import("cli.zig");

const capture = @import("capture.zig");
const generate = @import("generate.zig");
const imu = @import("imu.zig");
const icp = @import("icp.zig");

const commands = [_]cli.Command{
    .{ .name = "capture", .handler = capture.run },
    .{ .name = "generate", .handler = generate.run },
    .{ .name = "test-imu", .handler = imu.testImu },
    .{ .name = "icp", .handler = icp.run },
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try cli.parseArgs(allocator, args, &commands);
}
