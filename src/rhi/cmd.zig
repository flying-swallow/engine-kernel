const rhi = @import("rhi.zig");
const volk = @import("volk");
const vulkan = @import("vulkan.zig");
const std = @import("std");

pub const StageBits = struct {
    index_input: bool = false, //    index buffer consumption
    vertex_shader: bool = false, //    vertex shader
    tess_control_shader: bool = false, //    tessellation control (hull) shader
    tess_evaluation_shader: bool = false, //    tessellation evaluation (domain) shader
    geometry_shader: bool = false, //    geometry shader
    mesh_control_shader: bool = false, //    mesh control (task) shader
    mesh_evaluation_shader: bool = false, //    mesh evaluation (amplification) shader
    fragment_shader: bool = false, //    fragment (pixel) shader
    depth_stencil_attachment: bool = false, //    depth-stencil r/w operations
    color_attachment: bool = false, //    color r/w operations

    // compute                                    // invoked by  "cmddispatch*" (not rays)
    compute_shader: bool = false, //    compute shader

    // ray tracing                                // invoked by "cmddispatchrays*"
    raygen_shader: bool = false, //    ray generation shader
    miss_shader: bool = false, //    miss shader
    intersection_shader: bool = false, //    intersection shader
    closest_hit_shader: bool = false, //    closest hit shader
    any_hit_shader: bool = false, //    any hit shader
    callable_shader: bool = false, //    callable shader

    acceleration_structure: bool, // invoked by "cmd*accelerationstructure*"

    // copy
    copy: bool = false, // invoked by "cmdcopy*", "cmdupload*" and "cmdreadback*"
    clear_storage: bool = false, // invoked by "cmdclearstorage*"
    resolve: bool = false, // invoked by "cmdresolvetexture"

    // modifiers
    indirect: bool = false, // invoked by "indirect" command (used in addition to other bits)

};

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
//
//};

pub const AccessBits = struct {
    index_buffer: bool = false,
    vertex_buffer: bool = false,
    constant_buffer: bool = false,
    shader_resource: bool = false,
    shader_resource_storage: bool = false,
    argument_buffer: bool = false,
    color_attachment: bool = false,
    depth_stencil_attachment_write: bool = false,
    depth_stencil_attachment_read: bool = false,
    copy_source: bool = false,
    copy_destination: bool = false,
    resolve_source: bool = false,
    resolve_destination: bool = false,
    acceleration_structure_read: bool = false,
    acceleration_structure_write: bool = false,
    shading_rate_attachment: bool = false,
};

pub const Layout = enum(u8) {
    undefined = 0,
    color_attachment = 1,
    depth_stencil_attachment = 2,
    depth_stencil_read_only = 3,
    shader_resource = 4,
    shader_resource_storage = 5,
    copy_source = 6,
    copy_destination = 7,
    resolve_source = 8,
    resolve_destination = 9,
    present = 10,
    shading_rate_attachment = 11,
};

pub const Pool = struct {
    pub const Self = @This();
    backend: union(rhi.Backend) {
        vk: rhi.wrapper_platform_type(.vk, struct {
            queue: *rhi.Queue,
            pool: volk.c.VkCommandPool = null,
        }),
        dx12: rhi.wrapper_platform_type(.dx12, struct {}),
        mtl: void, // Metal does not use command pools
    },

    pub fn init(renderer: *rhi.Renderer, device: *rhi.Device, queue: *rhi.Queue) !Self {
        if (rhi.is_target_selected(.vk, renderer)) {
            var cmd_pool_create_info = volk.c.VkCommandPoolCreateInfo{
                .sType = volk.c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
                .flags = volk.c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
                .queueFamilyIndex = queue.backend.vk.family_index,
            };
            var pool: volk.c.VkCommandPool = null;
            try vulkan.wrap_err(volk.c.vkCreateCommandPool.?(device.backend.vk.device, &cmd_pool_create_info, null, &pool));
            return .{ .backend = .{ .vk = .{
                .queue = queue,
                .pool = pool,
            } } };
        } else if (rhi.is_target_selected(.dx12, renderer)) {} else if (rhi.is_target_selected(.mtl, renderer)) {}
        return error.UnsupportedBackend;
    }
};

pub const CommandringElement = union {
    vk: rhi.wrapper_platform_type(.vk, struct {
        semaphore: ?volk.c.VkSemaphore,
        fence: ?volk.c.VkFence,
        pool: *rhi.Pool,
        cmd: *rhi.Cmd,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
};

pub fn CommandRingBuffer(
    comptime options: struct {
        pool_count: usize, // number of command buffers in the ring
        cmd_per_pool: usize = 1, // number of command buffers per pool
        sync_primative: bool = false,
    },
) type {
    return struct {
        pub const Self = @This();
        pool_index: usize,
        cmd_index: usize,
        fence_index: usize,
        pools: [options.pool_count]rhi.Pool,
        cmds: [options.pool_count][options.cmd_per_pool]rhi.Cmd,
        backend: union {
            vk: rhi.wrapper_platform_type(.vk, struct {
                pool: *rhi.Pool,
                fences: if (options.sync_primative) [options.pool_count][options.cmd_per_pool]volk.c.VkFence else void,
                semaphores: if (options.sync_primative) [options.pool_count][options.cmd_per_pool]volk.c.VkSemaphore else void,
            }),
            dx12: rhi.wrapper_platform_type(.dx12, struct {}),
            mtl: rhi.wrapper_platform_type(.mtl, struct {}),
        },
        pub fn advance(self: *Self) void {
            self.pool_index = (self.cmd_index + 1) % options.pool_count;
            self.cmd_index = 0;
            self.fence_index = 0;
        }
        pub fn get(self: *Self, renderer: *rhi.Renderer, num_cmds: usize) CommandringElement {
            if (rhi.is_target_selected(.vk, renderer)) {
                std.debug.assert(num_cmds <= options.cmd_per_pool);
                std.debug.assert(num_cmds + self.cmd_index <= options.cmd_per_pool);
                const result = CommandringElement{ 
                    .vk = .{
                    .semaphore = if (options.sync_primative) self.backend.vk.semaphores[self.pool_index][self.fence_index] else null,
                    .fence = if (options.sync_primative) self.backend.vk.fences[self.pool_index][self.fence_index] else null,
                    .pool = &self.pools[self.pool_index],
                    .cmd = &self.cmds[self.pool_index][self.cmd_index..self.cmd_index + num_cmds],
                } };
                self.fence_index += 1;
                self.cmd_index += num_cmds;
                return result;
            }
            unreachable;
        }
        pub fn init(renderer: *rhi.Renderer, device: *rhi.Device, queue: *rhi.Queue) !Self {
            if (rhi.is_target_selected(.vk, renderer)) {
                const cmds: [options.pool_count][options.cmd_per_pool]rhi.Cmd = undefined;
                const pools: [options.pool_count]rhi.Pool = undefined;
                const semaphores: if (options.sync_primative) [options.pool_count][options.cmd_per_pool]volk.c.VkSemaphore else void = undefined;
                const fences: if (options.sync_primative) [options.pool_count][options.cmd_per_pool]volk.c.VkFence else void = undefined;
                for (0..options.pool_count) |pool_index| {
                    pools[pool_index] = try rhi.Pool.init(renderer, device, queue);
                    for(0..options.cmd_per_pool) |cmd_index| {
                        cmds[pool_index][cmd_index] = try rhi.Cmd.init(renderer, device, &pools[pool_index]);
                        if(options.sync_primative) {
                            var semaphore_create_info = volk.c.VkSemaphoreCreateInfo{
                                .sType = volk.c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
                            };
                            try vulkan.wrap_err(volk.c.vkCreateSemaphore.?(device.backend.vk.device, &semaphore_create_info, null, &semaphores[pool_index][cmd_index]));
                            var fence_create_info = volk.c.VkFenceCreateInfo{
                                .sType = volk.c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
                                .flags = volk.c.VK_FENCE_CREATE_SIGNALED_BIT,
                            };
                            try vulkan.wrap_err(volk.c.vkCreateFence.?(device.backend.vk.device, &fence_create_info, null, &fences[pool_index][cmd_index]));
                        }
                    }
                }
                return .{
                .pool_index = options.pool_count,
                .cmd_index = 0,
                .fence_index = 0,
                .cmds = cmds,
                .pools = pools,
                .backend = .{ .vk = .{
                    .cmds = cmds,
                    .semaphores = semaphores,
                    .fences = fences,
                } } };
            } else if (rhi.is_target_selected(.dx12, renderer)) {} else if (rhi.is_target_selected(.mtl, renderer)) {}

            unreachable; // should never reach here
        }
    };
}

pub const Cmd = @This();
backend: union(rhi.Backend) {
    vk: rhi.wrapper_platform_type(.vk, struct {
        cmd: volk.c.VkCommandBuffer = null,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
},

pub fn init(renderer: *rhi.Renderer, device: *rhi.Device, pool: *Pool) !Cmd {
    if (rhi.is_target_selected(.vk, renderer)) {
        var command: volk.c.VkCommandBuffer = null;
        var command_allocate_info = volk.c.VkCommandBufferAllocateInfo{
            .sType = volk.c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = pool.backend.vk.pool,
            .level = volk.c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
        };
        try vulkan.wrap_err(volk.c.vkAllocateCommandBuffers.?(device.backend.vk.device, &command_allocate_info, &command));
        return .{ .backend = .{ .vk = .{
            .cmd = command,
        } } };
    } else if (rhi.is_target_selected(.dx12, renderer)) {} else if (rhi.is_target_selected(.mtl, renderer)) {}
    return error.UnsupportedBackend;
}

pub fn begin(self: *Cmd, renderer: *rhi.Renderer) !void {
    if (rhi.is_target_selected(.vk, renderer)) {
        var device_group_begin_info = volk.c.VkDeviceGroupCommandBufferBeginInfoKHR{ .sType = volk.c.VK_STRUCTURE_TYPE_DEVICE_GROUP_COMMAND_BUFFER_BEGIN_INFO_KHR };
        var begin_info = volk.c.VkCommandBufferBeginInfo{
            .sType = volk.c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = volk.c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };
        vulkan.add_next(&begin_info, &device_group_begin_info);
        try vulkan.wrap_err(volk.c.vkBeginCommandBuffer.?(self.backend.vk.cmd, &begin_info));
    } else if (rhi.is_target_selected(.dx12, renderer)) {} else if (rhi.is_target_selected(.mtl, renderer)) {}
    return error.UnsupportedBackend;
}

pub fn end(self: *Cmd, renderer: *rhi.Renderer) !void {
    if (rhi.is_target_selected(.vk, renderer)) {
        try vulkan.wrap_err(volk.c.vkEndCommandBuffer.?(self.backend.vk.cmd));
    } else if (rhi.is_target_selected(.dx12, renderer)) {} else if (rhi.is_target_selected(.mtl, renderer)) {}
    return error.UnsupportedBackend;
}

//pub fn resourceBarrier(self: *Cmd, allocator: std.mem.Allocator, renderer: *rhi.Renderer, options: struct {
//    image_barrier: []const rhi.Image.Barrier,
//}) void {
//    if (rhi.is_target_selected(.vk, renderer)) {
//        var vk_image_barriers = try allocator.alloc(volk.c.VkImageMemoryBarrier, options.image_barrier.len);
//        defer allocator.free(vk_image_barriers);
//        for (options.image_barrier, 0..) |barrier, i| {
//            @memcpy(&vk_image_barriers[i], &barrier);
//        }
//        volk.c.vkCmdPipelineBarrier.?(self.backend.vk.cmd, volk.c.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, volk.c.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 0, null, 0, null, vk_image_barriers.len, vk_image_barriers.ptr);
//    } else if (rhi.is_target_selected(.dx12, renderer)) {} else if (rhi.is_target_selected(.mtl, renderer)) {}
//}
