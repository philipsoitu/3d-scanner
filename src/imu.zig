const std = @import("std");

const ioctl = @cImport({
    @cInclude("linux/i2c-dev.h");
    @cInclude("sys/ioctl.h");
});

pub fn testImu(allocator: std.mem.Allocator) !void {
    _ = allocator;
    std.debug.print("testing imu\n", .{});

    const i2cpath = "/dev/i2c-1";
    var file = try std.fs.cwd().openFile(i2cpath, .{ .mode = .read_write });
    defer file.close();

    const addr: c_int = 0x68; //MPU I2C address (from i2cdetect -y 1)

    if (ioctl.ioctl(file.handle, ioctl.I2C_SLAVE, addr) < 0) {
        return error.IoctlFailed;
    }

    // Wake up MPU6050
    try writeReg(file, 0x6B, 0);

    var data: [14]u8 = undefined;
    while (true) {
        try readReg(file, 0x3B, data[0..]);

        const accel_x = (@as(i16, @intCast((@as(i16, data[0]) << 8) | data[1])));
        const accel_y = (@as(i16, @intCast(((@as(i16, data[2]) << 8) | data[3]))));
        const accel_z = (@as(i16, @intCast(((@as(i16, data[4]) << 8) | data[5]))));
        const gyro_x = (@as(i16, @intCast(((@as(i16, data[8]) << 8) | data[9]))));
        const gyro_y = (@as(i16, @intCast(((@as(i16, data[10]) << 8) | data[11]))));
        const gyro_z = (@as(i16, @intCast(((@as(i16, data[12]) << 8) | data[13]))));

        std.debug.print("Accel X={} Y={} Z={} | Gyro X={} Y={} Z={}\n", .{ accel_x, accel_y, accel_z, gyro_x, gyro_y, gyro_z });

        std.Thread.sleep(500 * std.time.ns_per_ms);
    }
}

fn writeReg(fd: std.fs.File, reg: u8, data: u8) !void {
    var buf: [2]u8 = .{ reg, data };
    const written = try fd.writeAll(&buf);
    _ = written;
}

fn readReg(fd: std.fs.File, reg: u8, buf: []u8) !void {
    var r = [_]u8{reg};
    try fd.writeAll(&r);
    const read = try fd.readAll(buf);
    if (read != buf.len) return error.UnexpectedEOF;
}
