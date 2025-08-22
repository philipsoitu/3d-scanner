const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "_3d_scanner",
        .root_module = exe_mod,
    });

    exe.linkLibC();
    exe.linkSystemLibrary("freenect");

    // Pull in include path and lib path from env vars if set
    if (std.process.getEnvVarOwned(b.allocator, "FREENECT_INCLUDE")) |include_path| {
        exe.addIncludePath(.{ .cwd_relative = include_path });
    } else |_| {}

    if (std.process.getEnvVarOwned(b.allocator, "FREENECT_LIB")) |lib_path| {
        exe.addLibraryPath(.{ .cwd_relative = lib_path });
    } else |_| {}

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
