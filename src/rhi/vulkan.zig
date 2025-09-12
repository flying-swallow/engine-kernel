const std = @import("std");
const rhi = @import("rhi.zig");
pub const vk = @import("vulkan");
pub const volk = @import("volk");
pub const vma = @import("vma");

pub const default_device_extensions = &[_][:0]const u8{
    vk.extensions.khr_swapchain.name,
    vk.extensions.khr_maintenance_1.name,
    vk.extensions.khr_shader_draw_parameters,
    vk.extensions.ext_shader_subgroup_ballot,
    vk.extensions.ext_shader_subgroup_vote,
    vk.extensions.khr_dedicated_allocation,
    vk.extensions.khr_get_memory_requirements_2.name,

    vk.extensions.khr_draw_indirect_count.name,
    vk.extensions.ext_device_fault.name,
    // Fragment shader interlock extension to be used for ROV type functionality in Vulkan
    vk.extensions.ext_fragment_shader_interlock.name,

    //************************************************************************/
    // AMD Specific Extensions
    //************************************************************************/
    vk.extensions.amd_draw_indirect_count.name,
    vk.extensions.amd_shader_ballot.name,
    vk.extensions.amd_gcn_shader.name,
    vk.extensions.amd_buffer_marker.name,
    vk.extensions.amd_device_coherent_memory.name,
    //************************************************************************/
    // Multi GPU Extensions
    //************************************************************************/
    vk.extensions.khr_device_group.name,
    //************************************************************************/
    // Bindless & Non Uniform access Extensions
    //************************************************************************/
    vk.extensions.ext_descriptor_indexing.name,
    vk.extensions.khr_maintenance_3.name,
    // Required by raytracing and the new bindless descriptor API if we use it in future
    vk.extensions.khr_buffer_device_address.name,
    //************************************************************************/
    // Shader Atomic Int 64 Extension
    //************************************************************************/
    vk.extensions.khr_shader_atomic_int_64.name,
    //************************************************************************/
    //************************************************************************/
    vk.extensions.khr_ray_query.name,
    vk.extensions.khr_ray_tracing_pipeline.name,
    // Required by VK_KHR_ray_tracing_pipeline
    vk.extensions.khr_spirv_1_4.name,
    // Required by VK_KHR_spirv_1_4
    vk.extensions.khr_shader_float_controls.name,

    vk.extensions.khr_acceleration_structure.name,
    // Required by VK_KHR_acceleration_structure
    vk.extensions.khr_deferred_host_operations.name,
    //************************************************************************/
    // YCbCr format support
    //************************************************************************/
    // Requirement for VK_KHR_sampler_ycbcr_conversion
    vk.extensions.khr_bind_memory_2.name,
    vk.extensions.khr_sampler_ycbcr_conversion.name,
    vk.extensions.khr_bind_memory_2.name,
    vk.extensions.khr_image_format_list.name,
    vk.extensions.khr_image_format_list.name,
    vk.extensions.ext_sample_locations.name,
    //************************************************************************/
    // Dynamic rendering
    //************************************************************************/
    vk.extensions.khr_dynamic_rendering.name,
    vk.extensions.khr_depth_stencil_resolve.name, // Required by VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME
    vk.extensions.khr_create_renderpass_2.name, // Required by VK_KHR_DEPTH_STENCIL_RESOLVE_EXTENSION_NAME
    vk.extensions.khr_multiview.name, // Required by VK_KHR_CREATE_RENDERPASS_2_EXTENSION_NAME
    //************************************************************************/
    // Nsight Aftermath
    //************************************************************************/
    vk.extensions.ext_astc_decode_mode.name,
};

pub fn add_next(current: anytype, next: anytype) void {
    const tmp = current.p_next;
    current.p_next = next;
    next.p_next = tmp;
}

pub fn debug_utils_messenger(messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT, 
    _: vk.DebugUtilsMessageTypeFlagsEXT, callbackData: ?*const vk.DebugUtilsMessengerCallbackDataEXT, _: ?*anyopaque) callconv(vk.vulkan_call_conv) vk.Bool32 {
    if(messageSeverity.error_bit_ext == 1) {
        std.debug.print("VK ERROR: {s}\n", .{std.mem.span(callbackData.*.pMessage)});
    }
    if(messageSeverity.warning_bit_ext == 1) {
        std.debug.print("VK WARNING: {s}\n", .{std.mem.span(callbackData.*.pMessage)});
    }
    if(messageSeverity.info_bit_ext == 1) {
        std.debug.print("VK INFO: {s}\n", .{std.mem.span(callbackData.*.pMessage)});
    }
    return .false;
}

pub fn determains_aspect_mask(format: vk.Format, include_stencil: bool) vk.ImageAspectFlags {
    return switch (format) {
        .d16_unorm, .x8_d24_unorm_pack32, .d32_sfloat => vk.ImageAspectFlags {
            .dpth_bit = true
        },
        .s8_uint => vk.ImageAspectFlags{
            .stencil_bit = true
        },
        .d16_unorm_s8_uint, .d24_unorm_s8_uint, .d32_sfloat_s8_uint => vk.ImageAspectFlags{
            .depth_bit = true,
            .stencil_bit = include_stencil,
        }, 
        else => vk.ImageAspectFlags{.color_bit = true},
    };
}

pub fn vk_has_extension(properties: []const volk.c.VkExtensionProperties, val: []const u8) bool {
    for (properties) |prop| {
        if (std.mem.eql(u8, std.mem.sliceTo(prop.extensionName[0..], 0), val)) {
            return true;
        }
    }
    return false;
}

pub fn toShaderBytecode(comptime src: []const u8) [src.len / 4]u32 {
    var result: [src.len / 4]u32 = undefined;
    @memcpy(std.mem.sliceAsBytes(result[0..]), src);
    return result;
}

pub fn create_embeded_module(renderer: *rhi.Renderer,spv: []const u32, device: *rhi.Device) !volk.c.VkShaderModule {
    std.debug.assert(renderer.backend == .vulkan);
    var create_module: volk.c.VkShaderModule = undefined;
    var shader_module_create_info = vk.ShaderModuleCreateInfo {
        .sType = .shader_module_create_info,
        .code_size = spv.len,
        .p_code = spv.ptr,
    };
    
    try volk.c.vkCreateShaderModule.?(device.backend.vk.device, &shader_module_create_info, null, &create_module);
    return create_module;
}
