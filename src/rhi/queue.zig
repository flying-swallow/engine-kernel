const rhi = @import("rhi.zig");
const volk = @import("volk");
const std = @import("std");
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
},


pub fn submit(self: *Queue, renderer: *rhi.Renderer, options: struct {
    vk: ?rhi.wrapper_platform_type(.vk, struct {
        wait_semaphores: []const volk.c.VkSemaphore,
        mask_wait_stages: []const volk.c.VkPipelineStageFlags,
        signal_semaphores: []const volk.c.VkSemaphore,
        cmds: []const *rhi.Cmd,
    }),
    dx12: ?rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: ?rhi.wrapper_platform_type(.mtl, struct {}),
}) void{
    if (rhi.is_target_selected(.vk, renderer)) {
        std.debug.assert(options.vk != null);

        var submit_infos = volk.c.VkSubmitInfo{
            .sType = volk.c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .pNext = null,
            .waitSemaphoreCount = options.vk.?.wait_semaphores.len,
            .pWaitSemaphores = if (options.vk.?.wait_semaphores.len > 0) &options.vk.?.wait_semaphores[0] else null,
            .pWaitDstStageMask = if (options.vk.?.mask_wait_stages.len > 0) &options.vk.?.mask_wait_stages[0] else null,
            .commandBufferCount = options.vk.?.cmds.len,
            .pCommandBuffers = if (options.vk.?.cmds.len > 0) &options.vk.?.cmds[0].backend.vk.cmd else null,
            .signalSemaphoreCount = options.vk.?.signal_semaphores.len,
            .pSignalSemaphores = if (options.vk.?.signal_semaphores.len > 0) &options.vk.?.signal_semaphores[0] else null,
        };
        _ = rhi.vulkan.wrap_err(volk.c.vkQueueSubmit.?(self.backend.vk.queue, 1, &submit_infos, null));
    }

}

pub fn wait_queue_idle(self: *Queue, renderer: *rhi.Renderer) !void {
    if (rhi.is_target_selected(.vk, renderer)) {
        try rhi.vulkan.wrap_err(volk.c.vkQueueWaitIdle.?(self.vk.queue));
    }
}
