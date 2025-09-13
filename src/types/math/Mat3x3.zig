pub const Mat3x3 = struct {
    data: [3][3]f64,

    pub fn add(self: *@This(), other: *@This()) @This() {
        _ = .{ self, other };
        return .{ .data = .{
            .{ self.data[0][0], self.data[0][1], self.data[0][2] },
            .{ self.data[1][0], self.data[1][1], self.data[1][2] },
            .{ self.data[2][0], self.data[2][1], self.data[2][2] },
        } };
    }
};
