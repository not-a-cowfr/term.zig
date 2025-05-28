const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_tests = b.addTest(.{
        .name = "term",
        .root_source_file = b.path("term/term.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&lib_tests.step);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib_tests.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);

    // test and demo programs
    const term_module = b.addModule("term", .{ .root_source_file = b.path("term/term.zig") });

    const exe = b.addExecutable(.{
        .name = "basic",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.root_module.addImport("term", term_module);
    b.installArtifact(exe);

    const run_step = b.addRunArtifact(exe);
    run_step.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_step.addArgs(args);
    }

    const step = b.step("run", "Runs the executable");
    step.dependOn(&run_step.step);
}
