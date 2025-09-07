const rhi = @import("rhi.zig");
const volk = @import("volk");
const std = @import("std");
const vulkan = @import("vulkan.zig");

pub const Fence = @This();
backend: union {
    vk: rhi.wrapper_platform_type(.vk, struct {
        fence: volk.c.VkFence = null,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
} = undefined,

pub const FenceStatus = enum {
    complete,
    incomplete,
};

pub fn init(renderer: *rhi.Renderer, signaled: bool) !Fence {
    if (rhi.is_target_selected(.vk, renderer)) {
        var create_info: volk.c.VkFenceCreateInfo = .{
            .sType = volk.c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .pNext = null,
            .flags = if (signaled) volk.c.VK_FENCE_CREATE_SIGNALED_BIT else 0,
        };
        var fence: volk.c.VkFence = null;
        try rhi.vulkan.wrap_err(volk.c.vkCreateFence.?(renderer.backend.vk.device, &create_info, null, &fence));
        return .{
            .backend = .{
                .vk = .{
                    .fence = fence,
                }
            }
        };
    } else if (rhi.is_target_selected(.dx12, renderer)) {
    } else if (rhi.is_target_selected(.mtl, renderer)) {
    }
    return error.UnsupportedBackend;
}

pub fn wait_for_fences(comptime reserve: usize, device: *rhi.Device, renderer: *rhi.Renderer, fences: []const *Fence) !void {
    if (rhi.is_target_selected(.vk, renderer)) {
        std.debug.assert(fences.len <= reserve);
        var vk_fences: [reserve]volk.c.VkFence = undefined;
        for (fences, 0..) |fence, i| {
            vk_fences[i] = fence.backend.vk.fence;
        }
        try vulkan.wrap_err(volk.c.vkWaitForFences(device.backend.vk.device, fences.len, vk_fences.ptr, volk.c.VK_TRUE, std.math.maxInt(u64)));
    } else if (rhi.is_target_selected(.dx12, renderer)) {
    } else if (rhi.is_target_selected(.mtl, renderer)) {
    }
}

pub fn wait_for_fences_alloc(allocator: std.mem.Allocator,device: *rhi.Device, renderer: *rhi.Renderer, fences: []const *Fence) void {
    if (rhi.is_target_selected(.vk, renderer)) {
        var vk_fences = try allocator.alloc(volk.c.VkFence, fences.len);
        defer allocator.free(vk_fences);
        for (fences, 0..) |fence, i| {
            vk_fences[i] = fence.backend.vk.fence;
        }
        try vulkan.wrap_err(volk.c.vkWaitForFences(device.backend.vk.device, fences.len, vk_fences.ptr, volk.c.VK_TRUE, std.math.maxInt(u64)));
    } else if (rhi.is_target_selected(.dx12, renderer)) {
    } else if (rhi.is_target_selected(.mtl, renderer)) {
    }
}

pub fn get_fence_status(self: *Fence, device: *rhi.Device, renderer: *rhi.Renderer) !FenceStatus {
    if (rhi.is_target_selected(.vk, renderer)) {
        const status = volk.c.vkGetFenceStatus.?(device.backend.vk.device, self.backend.vk.fence);
        return switch (status) {
            volk.c.VK_SUCCESS => .complete,
            volk.c.VK_NOT_READY => .incomplete,
            else => unreachable, // should be unreachable due to wrap_err
        };
    } else if (rhi.is_target_selected(.dx12, renderer)) {
    } else if (rhi.is_target_selected(.mtl, renderer)) {
    }
    return error.UnsupportedBackend;
}
