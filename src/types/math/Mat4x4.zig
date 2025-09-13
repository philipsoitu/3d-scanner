const std = @import("std");
const Quaternion = @import("Quaternion.zig").Quaternion;

pub const Mat4x4 = struct {
    data: [4][4]f64,

    pub fn power_iter(self: *const @This()) Quaternion {
        var q: Quaternion = .{ .w = 1, .x = 0, .y = 0, .z = 0 };
        var tmp: Quaternion = undefined;
        for (0..50) |_| {
            tmp.w = self.data[0][0] * q.w + self.data[0][1] * q.x + self.data[0][2] * q.y + self.data[0][3] * q.z;
            tmp.x = self.data[1][0] * q.w + self.data[1][1] * q.x + self.data[1][2] * q.y + self.data[1][3] * q.z;
            tmp.y = self.data[2][0] * q.w + self.data[2][1] * q.x + self.data[2][2] * q.y + self.data[2][3] * q.z;
            tmp.z = self.data[3][0] * q.w + self.data[3][1] * q.x + self.data[3][2] * q.y + self.data[3][3] * q.z;
            const norm = std.math.sqrt(tmp.w * tmp.w + tmp.x * tmp.x + tmp.y * tmp.y + tmp.z * tmp.z);
            tmp.w /= norm;
            tmp.x /= norm;
            tmp.y /= norm;
            tmp.z /= norm;
            q = tmp;
        }
        return q;
    }
};
