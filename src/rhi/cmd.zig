const rhi = @import("rhi.zig");
const volk = @import("volk");
const vulkan = @import("vulkan.zig");
const std = @import("std");

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
            var cmd_pool_create_info = volk.c.VkCommandPoolCreateInfo {
                .sType = volk.c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
                .flags = volk.c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
                .queueFamilyIndex = queue.backend.vk.family_index,
            };
            var pool: volk.c.VkCommandPool = null;
            try vulkan.wrap_err(volk.c.vkCreateCommandPool.?(device.backend.vk.device, &cmd_pool_create_info, null, &pool));
            return .{
                .backend = .{
                    .vk = .{
                        .queue = queue,
                        .pool = pool,
                    }
                }
            };
        } else if (rhi.is_target_selected(.dx12, renderer)) {
        } else if (rhi.is_target_selected(.mtl, renderer)) {
        }
        return error.UnsupportedBackend;
    }
};

pub const Cmd = struct {
    pub const Self = @This();
    backend: union(rhi.Backend) {
        vk: rhi.wrapper_platform_type(.vk, struct {
            cmd: volk.c.VkCommandBuffer = null,
        }),
        dx12: rhi.wrapper_platform_type(.dx12, struct {}),
        mtl: rhi.wrapper_platform_type(.mtl, struct {}),
    },

    pub fn init(renderer: *rhi.Renderer, device: *rhi.Device, pool: *Pool) !Self {
        if (rhi.is_target_selected(.vk, renderer)) {
            var command: volk.c.VkCommandBuffer = null;
            var command_allocate_info = volk.c.VkCommandBufferAllocateInfo{
                .sType = volk.c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
                .commandPool = pool.backend.vk.pool,
                .level = volk.c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
                .commandBufferCount = 1,
            };
            try vulkan.wrap_err(volk.c.vkAllocateCommandBuffers.?(device.backend.vk.device, &command_allocate_info, &command));
            return .{
                .backend = .{
                    .vk = .{
                        .cmd = command,
                    }
                }
            };
        } else if (rhi.is_target_selected(.dx12, renderer)) {
        } else if (rhi.is_target_selected(.mtl, renderer)) {
        }
        return error.UnsupportedBackend;
    }

};


