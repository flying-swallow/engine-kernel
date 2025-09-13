const builtin = @import("builtin");


pub const volk = @import("volk");
pub const vulkan = @import("vulkan.zig");
pub const vma = @import("vma");
pub const format = @import("format.zig");
pub const renderer = @import("renderer.zig");
pub const device = @import("device.zig");
pub const queue = @import("queue.zig");
pub const physical_adapter = @import("physical_adapter.zig");
pub const swapchain = @import("swapchain.zig");
pub const descriptor = @import("descriptor.zig");
pub const cmd = @import("cmd.zig");
pub const image = @import("image.zig");
pub const sampler = @import("sampler.zig");
pub const buffer = @import("buffer.zig");
pub const fence = @import("fence.zig");
pub const pipeline_layout = @import("pipeline_layout.zig");
pub const pipeline = @import("pipeline.zig");
pub const resource_loader = @import("resource_loader.zig");

pub const Renderer = renderer.Renderer;
pub const PhysicalAdapter = physical_adapter.PhysicalAdapter;
pub const Queue = queue.Queue;
pub const Device = device.Device;
pub const Swapchain = swapchain.Swapchain;
pub const WindowHandle = swapchain.WindowHandle;
pub const Pool = cmd.Pool;
pub const Cmd = cmd.Cmd;
pub const Image = image.Image;
pub const Descriptor = descriptor.Descriptor;
pub const Sampler = sampler.Sampler;
pub const Format = format.Format;
pub const Buffer = buffer.Buffer;
pub const Fence = fence.Fence;
pub const ResourceLoader = resource_loader.ResourceLoader;
pub const PipelineLayout = pipeline_layout.PipelineLayout;
pub const GraphicsPipeline = pipeline.GraphicsPipeline;

//pub const StageBits = enum(u32) {
//    // Special
//    all = 0, // lazy default for barriers
//    none = 0x7fffffff,
//
//    // graphics                                   // invoked by "cmddraw*"
//    index_input = 1 << 0, //    index buffer consumption
//    vertex_shader = 1 << 1, //    vertex shader
//    tess_control_shader = 1 << 2, //    tessellation control (hull) shader
//    tess_evaluation_shader = 1 << 3, //    tessellation evaluation (domain) shader
//    geometry_shader = 1 << 4, //    geometry shader
//    mesh_control_shader = 1 << 5, //    mesh control (task) shader
//    mesh_evaluation_shader = 1 << 6, //    mesh evaluation (amplification) shader
//    fragment_shader = 1 << 7, //    fragment (pixel) shader
//    depth_stencil_attachment = 1 << 8, //    depth-stencil r/w operations
//    color_attachment = 1 << 9, //    color r/w operations
//
//    // compute                                    // invoked by  "cmddispatch*" (not rays)
//    compute_shader = 1 << 10, //    compute shader
//
//    // ray tracing                                // invoked by "cmddispatchrays*"
//    raygen_shader = 1 << 11, //    ray generation shader
//    miss_shader = 1 << 12, //    miss shader
//    intersection_shader = 1 << 13, //    intersection shader
//    closest_hit_shader = 1 << 14, //    closest hit shader
//    any_hit_shader = 1 << 15, //    any hit shader
//    callable_shader = 1 << 16, //    callable shader
//
//    acceleration_structure = 1 << 17, // invoked by "cmd*accelerationstructure*"
//
//    // copy
//    copy = 1 << 18, // invoked by "cmdcopy*", "cmdupload*" and "cmdreadback*"
//    clear_storage = 1 << 19, // invoked by "cmdclearstorage*"
//    resolve = 1 << 20, // invoked by "cmdresolvetexture"
//
//    // modifiers
//    indirect = 1 << 21, // invoked by "indirect" command (used in addition to other bits)
//
//    // umbrella stages
//    tessellation_shaders = .tess_control_shader | .tess_evaluation_shader,
//    mesh_shaders = .mesh_control_shader | .mesh_evaluation_shader,
//
//    graphics_shaders = .vertex_shader |
//        .tessellation_shaders |
//        .geometry_shader |
//        .mesh_shaders |
//        .fragment_shader,
//
//    // invoked by "cmddispatchrays"
//    ray_tracing_shaders = .raygen_shader |
//        .miss_shader |
//        .intersection_shader |
//        .closest_hit_shader |
//        .any_hit_shader |
//        .callable_shader,
//
//    // invoked by "cmddraw*"
//    draw = .index_input |
//        .graphics_shaders |
//        .depth_stencil_attachment |
//        .color_attachment,
//};


pub const Selection = enum {
    default, 
    vk,
    dx12,
    mtl
};

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

pub fn select(ren: *Renderer ,comptime T: type, pass: T, comptime predicate: fn(comptime target: Backend, val: T) void) void {
    for (platform_api) |api| {
        if(ren.backend == api){
            predicate(api, pass);
            return;
        }
    }
}

pub fn wrapper_platform_type(api: Backend, comptime impl: type) type {
    if(platform_has_api(api)){
        return impl;
    } else {
        return void;
    }
}

