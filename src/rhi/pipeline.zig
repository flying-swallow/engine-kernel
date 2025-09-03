const rhi = @import("rhi.zig");
const volk = @import("volk");

pub const VulkanCacheSlot = struct {
    pub const Self = @This();

};

pub const DescriptorSetBinding = struct {
};

pub const Pipeline = @This();
backend: union(rhi.Backend) {
    vk: rhi.wrapper_platform_type(.vk, struct {
        pipeline: volk.c.VkPipeline = null,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
},

pub fn init(renderer: *rhi.Renderer) !Pipeline {
    if (rhi.is_target_selected(.vk, renderer)) {
        return .{
            .backend = .{
                .vk = .{
                }
            }
        };
    } else if (rhi.is_target_selected(.dx12, renderer)) {
    } else if (rhi.is_target_selected(.mtl, renderer)) {
    }
    return error.UnsupportedBackend;
}
