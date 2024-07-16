const std = @import("std");
const sdl = @import("thirdparty/sdl_zig/build.zig");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const sdk = sdl.init(b, null, null);
    const exe = b.addExecutable(.{
        .name = "gamefun",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    sdk.link(exe, .dynamic, .SDL2);

    // const registry = b.dependency("vulkan_headers", .{}).path("thirdparty/vulkan/vk.xml");
    const registry = "thirdparty/vulkan/vk.xml";
    const vk_gen = b.dependency("vulkan_zig", .{}).artifact("vulkan-zig-generator");
    const vk_gen_cmd = b.addRunArtifact(vk_gen);
    vk_gen_cmd.addArg(registry);
    const vk_zig = b.addModule("vulkan-zig", .{
        .root_source_file = vk_gen_cmd.addOutputFileArg("vk.zig"),
    });

    exe.root_module.addImport("vk", vk_zig);
    exe.root_module.addImport("sdl2", sdk.getNativeModuleVulkan(vk_zig));

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
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

    const test_step = b.step("test", "Run unit tests");

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const gen_arena_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/gen_arena.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_gen_arena_unit_tests = b.addRunArtifact(gen_arena_unit_tests);

    const util_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/util.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_util_unit_tests = b.addRunArtifact(util_unit_tests);

    const world_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/util.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_world_unit_tests = b.addRunArtifact(world_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    test_step.dependOn(&run_gen_arena_unit_tests.step);
    test_step.dependOn(&run_util_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_world_unit_tests.step);
}