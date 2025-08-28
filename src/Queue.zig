const std = @import("std");
const Frame = @import("frame.zig").Frame;

pub const Queue = struct {
    allocator: std.mem.Allocator,
    list: std.ArrayList(Frame),
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    done: bool = false,

    pub fn init(allocator: std.mem.Allocator) Queue {
        return Queue{
            .allocator = allocator,
            .list = std.ArrayList(Frame){},
        };
    }

    pub fn deinit(self: *Queue) void {
        self.list.deinit(self.allocator);
    }

    pub fn push(self: *Queue, frame: Frame) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.list.append(self.allocator, frame);
        self.cond.signal();
    }

    pub fn pop(self: *Queue) ?Frame {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.list.items.len == 0 and !self.done) {
            self.cond.wait(&self.mutex);
        }

        if (self.list.items.len == 0 and self.done) {
            return null;
        }

        return self.list.orderedRemove(0);
    }

    pub fn finish(self: *Queue) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.done = true;
        self.cond.broadcast();
    }
};
