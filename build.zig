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
    const zwindows = b.dependency("zwindows", .{
        .zxaudio2_debug_layer = (builtin.mode == .Debug),
        .zd3d12_debug_layer = (builtin.mode == .Debug),
        .zd3d12_gbv = b.option(bool, "zd3d12_gbv", "Enable GPU-Based Validation") orelse false,
    });
    const engine_module = b.addModule("enginekit" ,.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zwindows", .module = zwindows.module("zwindows") },
            .{ .name = "zd3d12", .module = zwindows.module("zd3d12") },
            .{ .name = "zxaudio2", .module = zwindows.module("zxaudio2") },
        },
    });
    const lib = b.addLibrary(.{
        .name = "enginekit",
        .linkage = .static, 
        .root_module = engine_module 
    });
   
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

    const registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml");      
    const vulkan = b.dependency("vulkan", .{
        .registry = registry,
    }).module("vulkan-zig");
    engine_module.addImport("vulkan", vulkan);


    const activate_zwindows = @import("zwindows").activateSdk(b, zwindows);
    lib.step.dependOn(activate_zwindows);
    
    // Install vendored binaries
    @import("zwindows").install_xaudio2(&lib.step, zwindows, .bin);
    @import("zwindows").install_d3d12(&lib.step, zwindows, .bin);
    @import("zwindows").install_directml(&lib.step, zwindows, .bin);

    b.installArtifact(lib);
    const mod_tests = b.addTest(.{
        .root_module = engine_module,
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
