const std = @import("std");
const rlz = @import("raylib_zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const use_llvm = b.option(bool, "llvm", "Force using LLVM for codegen");

    var options = b.addOptions();

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "game_of_life",
        .root_module = exe_mod,
        .use_llvm = use_llvm,
    });

    const rl_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        // fullscreen broken on wayland, workaround broken on x
        .linux_display_backend = rlz.LinuxDisplayBackend.X11,
    });

    const raylib = rl_dep.module("raylib");
    const raygui = rl_dep.module("raygui");
    const rl_artifact = rl_dep.artifact("raylib");

    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);
    exe.linkLibrary(rl_artifact);

    const resources = b.createModule(.{ .root_source_file = b.path("resources/resources.zig") });
    exe.root_module.addImport("resources", resources);

    var patterns = try getPatterns(b);
    var pattern_iter = patterns.iterator();
    while (pattern_iter.next()) |pat| {
        options.addOption([]const []const u8, pat.key_ptr.*, pat.value_ptr.*);
        b.allocator.free(pat.key_ptr.*);
        b.allocator.free(pat.value_ptr.*);
    }
    patterns.deinit();
    exe.root_module.addOptions("resources", options);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn getPatterns(b: *std.Build) !std.StringHashMap([]const []const u8) {
    var dir = try b.build_root.handle.openDir("resources/patterns", .{ .iterate = true });
    defer dir.close();

    var categories = std.StringHashMap([]const []const u8).init(b.allocator);

    var cat_iter = dir.iterate();
    while (cat_iter.next() catch null) |cat_entry| {
        if (cat_entry.kind != .directory) continue;

        var category = try dir.openDir(cat_entry.name, .{ .iterate = true });
        defer category.close();

        var patterns = std.array_list.Managed([]const u8).init(b.allocator);

        var pat_iter = category.iterate();
        while (pat_iter.next() catch null) |pat_entry| {
            if (pat_entry.kind != .file) continue;

            const file = try category.openFile(pat_entry.name, .{});
            defer file.close();

            try patterns.append(try file.readToEndAlloc(b.allocator, std.math.maxInt(usize)));
        }

        const name = try b.allocator.alloc(u8, cat_entry.name.len);
        @memcpy(name, cat_entry.name);
        try categories.put(name, try patterns.toOwnedSlice());
    }

    return categories;
}
