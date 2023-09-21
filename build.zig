const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(
        .{
            .name = "zigout",
            .root_source_file = .{ .path = "src/main.zig" },
            .target = target,
            .optimize = optimize,
        },
    );
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    exe.linkSystemLibrary("sdl2");
    exe.linkLibC();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
