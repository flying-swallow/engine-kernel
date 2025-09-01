const volk = @import("volk");
const vma = @import("vma");
const vulkan = @import("vulkan.zig");
const builtin = @import("builtin");

const renderer = @import("renderer.zig");
const device = @import("device.zig");
const texture = @import("texture.zig");
const queue = @import("queue.zig");
const physical_adapter = @import("physical_adapter.zig");
const swapchain = @import("swapchain.zig");

pub const Renderer = renderer.Renderer;
pub const PhysicalAdapter = physical_adapter.PhysicalAdapter;
pub const Queue = queue.Queue;
pub const Device = device.Device;
pub const Swapchain = swapchain.Swapchain;

pub const Backend = enum {
    vk,
    dx12,
    mtl,
};

pub const platform_api = blk: {
    switch (builtin.os.tag) {
        .windows => break :blk [_]Backend{ .vk, .dx12 },
        .linux => break :blk [_]Backend{ .vk },
        .macos => break :blk [_]Backend{ .mtl },
        .ios => break :blk [_]Backend{ .mtl },
        else => break :blk [_]Backend{},
    }
};


pub fn platform_has_api(comptime target: Backend) bool {
    for (platform_api) |t| {
        if (t == target) return true;
    }
    return false;
}

pub fn is_target_selected(comptime api: Backend, ren: *Renderer) bool{
    switch(api) {
        .vk => return platform_has_api(.vk) and ren.backend == .vk,
        .dx12 => return platform_has_api(.dx12) and ren.backend == .dx12,
        .mtl => return platform_has_api(.mtl) and ren.backend == .mtl,
    }
}


pub fn wrapper_platform_type(api: Backend, comptime impl: type) type{
    if(platform_has_api(api)){
        return impl;
    } else {
        return void;
    }
}

