const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const demo = b.option(bool, "demo", "Build and run demo mode without drawfs") orelse false;

    const mod = b.addModule("pathd", .{
        .root_source_file = b.path("src/pathd.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "pathd",
        .root_source_file = b.path("src/pathd_main/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("pathd", mod);
    exe.root_module.addOptions("build_options", .{ .demo = demo });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run pathd");
    run_step.dependOn(&run_cmd.step);
}
