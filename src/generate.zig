const std = @import("std");

pub fn run(allocator: std.mem.Allocator) !void {
    _ = allocator;
    std.debug.print("generate\n", .{});
}
