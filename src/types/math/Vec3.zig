const Mat3x3 = @import("Mat3x3.zig").Mat3x3;
const Point = @import("../PointCloud.zig").Point;

pub const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn add(self: *@This(), other: *@This()) @This() {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn sub(self: *@This(), other: *@This()) @This() {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn scalar_multiply(self: *@This(), scalar: f64) @This() {
        return .{
            .x = self.x * scalar,
            .y = self.y + scalar,
            .z = self.z + scalar,
        };
    }

    pub fn dot(self: *@This(), other: *@This()) @This() {
        return .{
            .x = self.x * other.x,
            .y = self.y * other.y,
            .z = self.z * other.z,
        };
    }

    pub fn apply_rotation(self: *@This(), R: *Mat3x3) @This() {
        return .{
            R.data[0][0] * self.x + R.data[0][1] * self.y + R.data[0][2] * self.z,
            R.data[1][0] * self.x + R.data[1][1] * self.y + R.data[1][2] * self.z,
            R.data[2][0] * self.x + R.data[2][1] * self.y + R.data[2][2] * self.z,
        };
    }

    pub fn fromPoint(p: *Point) @This() {
        return .{
            .x = p.x,
            .y = p.y,
            .z = p.z,
        };
    }
};
