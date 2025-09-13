const std = @import("std");
const Quaternion = @import("Quaternion.zig").Quaternion;

pub const Mat4x4 = struct {
    data: [4][4]f64,

    pub fn power_iter(self: *@This()) Quaternion {
        var q: Quaternion = .{ .w = 1, .x = 0, .y = 0, .z = 0 };
        var tmp: Quaternion = undefined;
        for (0..50) |_| {
            tmp[0] = self.data[0][0] * q[0] + self.data[0][1] * q[1] + self.data[0][2] * q[2] + self.data[0][3] * q[3];
            tmp[1] = self.data[1][0] * q[0] + self.data[1][1] * q[1] + self.data[1][2] * q[2] + self.data[1][3] * q[3];
            tmp[2] = self.data[2][0] * q[0] + self.data[2][1] * q[1] + self.data[2][2] * q[2] + self.data[2][3] * q[3];
            tmp[3] = self.data[3][0] * q[0] + self.data[3][1] * q[1] + self.data[3][2] * q[2] + self.data[3][3] * q[3];
            const norm = std.math.sqrt(tmp[0] * tmp[0] + tmp[1] * tmp[1] + tmp[2] * tmp[2] + tmp[3] * tmp[3]);
            tmp[0] /= norm;
            tmp[1] /= norm;
            tmp[2] /= norm;
            tmp[3] /= norm;
            q = tmp;
        }
        return q;
    }
};
