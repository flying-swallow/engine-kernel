const rhi = @import("rhi.zig");
const volk = @import("volk");
const vma = @import("vma");

pub const Barrier = struct {
    pub const Self = @This();
    backend: union {
        vk: rhi.wrapper_platform_type(.vk, struct {
			stage: volk.c.VkPipelineStageFlags2, 
			access: volk.c.VkAccessFlags2,
			layout: volk.c.VkImageLayout
        }),
        dx12: rhi.wrapper_platform_type(.dx12, struct {}),
        mtl: rhi.wrapper_platform_type(.mtl, struct {}),
    }
};

pub const Image = @This();
backend: union {
    vk: rhi.wrapper_platform_type(.vk, struct {
        image: volk.c.VkImage,
        allocation: vma.c.VmaAllocation,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
},

