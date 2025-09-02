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
    const upstream = b.dependency("volk", .{});
    const vulkan = b.dependency("vulkan", .{});
    const module = b.addModule("volk", .{ .root_source_file = b.path("root.zig") });
    module.addIncludePath(upstream.path(""));
    module.addIncludePath(vulkan.path("include"));

    const lib = b.addLibrary(.{
        .name = "volk",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    lib.linkLibC();
    lib.linkLibCpp(); 

    var flags = std.ArrayList([]const u8).empty;
    defer flags.deinit(b.allocator);
    if(builtin.os.tag == .windows) {
        try flags.appendSlice(b.allocator,&.{
            "-DVK_USE_PLATFORM_WIN32_KHR"
        });
    } else if (builtin.os.tag == .linux) {
        try flags.appendSlice(b.allocator, &.{
            "-DVK_USE_PLATFORM_XLIB_KHR",
            "-DVK_USE_PLATFORM_WAYLAND_KHR"
        });
    } else if (builtin.os.tag == .macos or builtin.os.tag == .ios) {
        try flags.appendSlice(b.allocator,&.{
            "-DVK_USE_PLATFORM_METAL_EXT"
        });
    }
    lib.addCSourceFiles(.{
        .root = upstream.path(""),
        .flags = flags.items,
        .files = &.{
            "volk.c"
        } 
    });
    lib.installHeadersDirectory(
        vulkan.path("include"),
        "",
        .{ .include_extensions = &.{".h"} },
    );
    lib.installHeadersDirectory(
        upstream.path(""),
        "",
        .{ .include_extensions = &.{".h"} },
    );

    b.installArtifact(lib);
}

