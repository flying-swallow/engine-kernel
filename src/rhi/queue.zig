const rhi = @import("rhi.zig");
const volk = @import("volk");

pub const Queue = @This();

backend: union(rhi.Backend) {
    vk: rhi.wrapper_platform_type(.vk, struct {
        queue_flags: volk.c.VkQueueFlags = 0,
        family_index: u32 = 0,
        slot_index: u32 = 0,
        queue: volk.c.VkQueue = null,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
}
