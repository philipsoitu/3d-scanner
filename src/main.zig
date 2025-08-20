const std = @import("std");
const frame = @import("frame.zig");
const kinect = @import("kinect.zig");

pub fn main() !void {
    var k = try kinect.Kinect.init();
    defer k.shutdown();

    while (true) {
        std.Thread.sleep(100_000);
        std.debug.print(".", .{});
    }
}
