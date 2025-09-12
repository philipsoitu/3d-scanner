const std = @import("std");
const Vec3 = @import("types/math/Vec3.zig").Vec3;
const Mat3x3 = @import("types/math/Mat3x3.zig").Mat3x3;
const Quaternion = @import("types/math/Quaternion.zig").Quaternion;

pub fn run(allocator: std.mem.Allocator) !void {
    _ = allocator;
    std.debug.print("test\n", .{});
}
