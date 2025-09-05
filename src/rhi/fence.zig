const rhi = @import("rhi.zig");
const volk = @import("volk");

pub const Fence = @This();
backend: union {
    vk: rhi.wrapper_platform_type(.vk, struct {
        fence: volk.c.VkFence = null,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
} = undefined,


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

