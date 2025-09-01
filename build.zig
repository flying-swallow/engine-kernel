const std = @import("std");
const builtin = @import("builtin");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("enginekit", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
   
    const engine_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "enginekit", .module = mod },
        },
    });
   
    const lib = b.addLibrary(.{
        .name = "enginekit",
        .linkage = .static, 
        .root_module = engine_module 
    });

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        //.preferred_linkage = .static,
        //.strip = null,
        //.sanitize_c = null,
        //.pic = null,
        //.lto = null,
        //.emscripten_pthreads = false,
        //.install_build_config_h = false,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    engine_module.linkLibrary(sdl_lib);

    //const exe = b.addExecutable(.{
    //    .name = "GraphicsKernel",
    //    .root_module = engine_module 
    //});

    const zwindows = b.dependency("zwindows", .{
        .zxaudio2_debug_layer = (builtin.mode == .Debug),
        .zd3d12_debug_layer = (builtin.mode == .Debug),
        .zd3d12_gbv = b.option(bool, "zd3d12_gbv", "Enable GPU-Based Validation") orelse false,
    });
    const activate_zwindows = @import("zwindows").activateSdk(b, zwindows);
    lib.step.dependOn(activate_zwindows);
    
    // Import the Windows API bindings
    lib.root_module.addImport("zwindows", zwindows.module("zwindows"));

    // Import the optional zd3d12 helper library
    lib.root_module.addImport("zd3d12", zwindows.module("zd3d12"));

    // Import the optional zxaudio2 helper library
    lib.root_module.addImport("zxaudio2", zwindows.module("zxaudio2"));
    
    // Install vendored binaries
    @import("zwindows").install_xaudio2(&lib.step, zwindows, .bin);
    @import("zwindows").install_d3d12(&lib.step, zwindows, .bin);
    @import("zwindows").install_directml(&lib.step, zwindows, .bin);
    
    if (b.lazyDependency("volk", .{
        .target = target,
        .optimize = optimize,
    })) |volk_dep| {
        engine_module.addImport(
            "volk",
            volk_dep.module("volk"),
        );
        engine_module.linkLibrary(volk_dep.artifact("volk"));
    }

    if(b.lazyDependency("vma", .{
        .target = target,
        .optimize = optimize,
    })) |vma_dep| {
        engine_module.addImport(
            "vma",
            vma_dep.module("vma"),
        );
        engine_module.linkLibrary(vma_dep.artifact("vma"));
    }

    b.installArtifact(lib);
    //const run_step = b.step("run", "Run the app");
    //const run_cmd = b.addRunArtifact(exe);
    //run_step.dependOn(&run_cmd.step);
    //run_cmd.step.dependOn(b.getInstallStep());
    //if (b.args) |args| {
    //    run_cmd.addArgs(args);
    //}
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);
    const exe_tests = b.addTest(.{
        .root_module = engine_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
