const std = @import("std");

pub const BufferPool = struct {
    allocator: *std.mem.Allocator,
    free_list: std.ArrayList([]u8),
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},

    pub fn init(allocator: *std.mem.Allocator, count: usize, size: usize) !BufferPool {
        var pool = BufferPool{
            .allocator = allocator,
            .free_list = std.ArrayList([]u8).init(allocator.*),
        };
        try pool.free_list.ensureTotalCapacity(count);
        for (0..count) |_| {
            const buf = try allocator.alloc(u8, size);
            try pool.free_list.append(buf);
        }
        return pool;
    }

    pub fn deinit(self: *BufferPool) void {
        for (self.free_list.items) |buf| {
            self.allocator.free(buf);
        }
        self.free_list.deinit();
    }

    pub fn acquire(self: *BufferPool) []u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.free_list.items.len == 0) {
            self.cond.wait(&self.mutex);
        }
        return self.free_list.pop();
    }

    pub fn release(self: *BufferPool, buf: []u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.free_list.append(buf) catch unreachable;
        self.cond.signal();
    }
};
