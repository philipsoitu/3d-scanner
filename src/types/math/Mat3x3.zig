pub const Mat3x3 = struct {
    data: [3][3]f64,

    pub fn add(self: *const @This(), other: *const @This()) @This() {
        return .{ .data = .{
            .{ self.data[0][0] + other.data[0][0], self.data[0][1] + other.data[0][1], self.data[0][2] + other.data[0][2] },
            .{ self.data[1][0] + other.data[1][0], self.data[1][1] + other.data[1][1], self.data[1][2] + other.data[1][2] },
            .{ self.data[2][0] + other.data[2][0], self.data[2][1] + other.data[2][1], self.data[2][2] + other.data[2][2] },
        } };
    }
};
