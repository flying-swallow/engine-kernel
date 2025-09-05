const rhi = @import("rhi.zig");
const volk = @import("volk");
const vma = @import("vma");
const std = @import("std");

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

pub fn get_mapped_region(self: *Buffer, offset: usize, size: usize) !MappedMemoryRange {
    if (self.mapped_region) |region| {
        return .{
            .buffer = self,
            .memory_range = region[offset .. offset + size]
        };
    } 
    return error.BufferNotMapped;
}

pub const MappedMemoryRange = struct {
    pub const Self = @This();
    buffer: Buffer, 
    memory_range: []u8,
};

