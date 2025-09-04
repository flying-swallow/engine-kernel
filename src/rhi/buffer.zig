const rhi = @import("rhi.zig");
const volk = @import("volk");
const vma = @import("vma");

pub const Barrier = struct {
    pub const Self = @This();
    backend: union {
        vk: rhi.wrapper_platform_type(.vk, struct {
            stage: volk.c.VkPipelineStageFlags2,
            access: volk.c.VkAccessFlags2,
        }),
        dx12: rhi.wrapper_platform_type(.dx12, struct {}),
        mtl: rhi.wrapper_platform_type(.mtl, struct {

        }),
    }
};

pub const Buffer = @This();
mapped_region: ?[]u8 = null,
backend: union {
    vk: rhi.wrapper_platform_type(.vk, struct {
        buffer: volk.c.VkBuffer = null,
        allocation: vma.c.VmaAllocation = null,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
} = undefined,

pub const MappedMemoryRange = struct {
    pub const Self = @This();
    buffer: *Buffer,
    memory_range: []u8,
};

