const rhi = @import("rhi.zig");
const volk = @import("volk");
const std = @import("std");
const vulkan = @import("vulkan.zig");

pub const GraphicsPipeline = struct {
    backend: union {
        vk: rhi.wrapper_platform_type(.vk, struct {
            pipeline: volk.c.VkPipeline = null,
        }),
        dx12: rhi.wrapper_platform_type(.dx12, struct {}),
        mtl: rhi.wrapper_platform_type(.mtl, struct {}),
    },
};

