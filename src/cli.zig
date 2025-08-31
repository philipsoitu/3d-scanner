const std = @import("std");

pub const Command = struct {
    name: []const u8,
    handler: *const fn (allocator: std.mem.Allocator) anyerror!void,
};

pub fn parseArgs(
    allocator: std.mem.Allocator,
    args: []const []const u8,
    commands: []const Command,
) !void {
    var i: usize = 1; // Skip executable name
    while (i < args.len) {
        const arg = args[i];
        var found = false;

        for (commands) |cmd| {
            if (std.mem.eql(u8, arg, cmd.name)) {
                found = true;
                try cmd.handler(allocator);
                break;
            }
        }

        if (!found) {
            return error.UnknownCommand;
        }

        i += 1;
    }
}
