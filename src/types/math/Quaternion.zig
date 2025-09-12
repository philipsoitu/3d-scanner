const Mat3x3 = @import("Mat3x3.zig").Mat3x3;

pub const Quaternion = struct {
    w: f64,
    x: f64,
    y: f64,
    z: f64,

    pub fn normalize(q: *@This()) void {
        const lenSq = q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z;
        if (lenSq == 0) {
            q.* = Quaternion{ .w = 1, .x = 0, .y = 0, .z = 0 };
            return;
        }
        const invLen = 1.0 / @sqrt(lenSq);
        q.w *= invLen;
        q.x *= invLen;
        q.y *= invLen;
        q.z *= invLen;
    }

    pub fn toRotationMatrix(self: *@This()) Mat3x3 {
        return Mat3x3{ .data = .{
            .{ 1 - 2 * self.y * self.y - 2 * self.z * self.z, 2 * self.x * self.y - 2 * self.w * self.z, 2 * self.x * self.z + 2 * self.w * self.y },
            .{ 2 * self.x * self.y + 2 * self.w * self.z, 1 - 2 * self.x * self.x - 2 * self.z * self.z, 2 * self.y * self.z - 2 * self.w * self.x },
            .{ 2 * self.x * self.z - 2 * self.w * self.y, 2 * self.y * self.z + 2 * self.w * self.x, 1 - 2 * self.x * self.x - 2 * self.y * self.y },
        } };
    }
};
