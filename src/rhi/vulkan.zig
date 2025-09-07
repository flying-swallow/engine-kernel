const volk = @import("volk");
const std = @import("std");

pub const default_device_extensions = &[_][:0]const u8 {
    volk.c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    volk.c.VK_KHR_MAINTENANCE1_EXTENSION_NAME,
    volk.c.VK_KHR_SHADER_DRAW_PARAMETERS_EXTENSION_NAME,
    volk.c.VK_EXT_SHADER_SUBGROUP_BALLOT_EXTENSION_NAME,
    volk.c.VK_EXT_SHADER_SUBGROUP_VOTE_EXTENSION_NAME,
    volk.c.VK_KHR_DEDICATED_ALLOCATION_EXTENSION_NAME,
    volk.c.VK_KHR_GET_MEMORY_REQUIREMENTS_2_EXTENSION_NAME,

    volk.c.VK_KHR_DRAW_INDIRECT_COUNT_EXTENSION_NAME,
    volk.c.VK_EXT_DEVICE_FAULT_EXTENSION_NAME,
    // Fragment shader interlock extension to be used for ROV type functionality in Vulkan
    volk.c.VK_EXT_FRAGMENT_SHADER_INTERLOCK_EXTENSION_NAME,

    //************************************************************************/
    // AMD Specific Extensions
    //************************************************************************/
    volk.c.VK_AMD_DRAW_INDIRECT_COUNT_EXTENSION_NAME,
    volk.c.VK_AMD_SHADER_BALLOT_EXTENSION_NAME,
    volk.c.VK_AMD_GCN_SHADER_EXTENSION_NAME,
    volk.c.VK_AMD_BUFFER_MARKER_EXTENSION_NAME,
    volk.c.VK_AMD_DEVICE_COHERENT_MEMORY_EXTENSION_NAME,
    //************************************************************************/
    // Multi GPU Extensions
    //************************************************************************/
    volk.c.VK_KHR_DEVICE_GROUP_EXTENSION_NAME,
    //************************************************************************/
    // Bindless & Non Uniform access Extensions
    //************************************************************************/
    volk.c.VK_EXT_DESCRIPTOR_INDEXING_EXTENSION_NAME,
    volk.c.VK_KHR_MAINTENANCE3_EXTENSION_NAME,
    // Required by raytracing and the new bindless descriptor API if we use it in future
    volk.c.VK_KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME,
    //************************************************************************/
    // Shader Atomic Int 64 Extension
    //************************************************************************/
    volk.c.VK_KHR_SHADER_ATOMIC_INT64_EXTENSION_NAME,
    //************************************************************************/
    // Raytracing
    //************************************************************************/
    volk.c.VK_KHR_RAY_QUERY_EXTENSION_NAME,
    volk.c.VK_KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME,
    // Required by VK_KHR_ray_tracing_pipeline
    volk.c.VK_KHR_SPIRV_1_4_EXTENSION_NAME,
    // Required by VK_KHR_spirv_1_4
    volk.c.VK_KHR_SHADER_FLOAT_CONTROLS_EXTENSION_NAME,

    volk.c.VK_KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME,
    // Required by VK_KHR_acceleration_structure
    volk.c.VK_KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME,
    //************************************************************************/
    // YCbCr format support
    //************************************************************************/
    // Requirement for VK_KHR_sampler_ycbcr_conversion
    volk.c.VK_KHR_BIND_MEMORY_2_EXTENSION_NAME,
    volk.c.VK_KHR_SAMPLER_YCBCR_CONVERSION_EXTENSION_NAME,
    volk.c.VK_KHR_BIND_MEMORY_2_EXTENSION_NAME,
    volk.c.VK_KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME,
    volk.c.VK_KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME,
    volk.c.VK_EXT_SAMPLE_LOCATIONS_EXTENSION_NAME,
    //************************************************************************/
    // Dynamic rendering
    //************************************************************************/
    volk.c.VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME,
    volk.c.VK_KHR_DEPTH_STENCIL_RESOLVE_EXTENSION_NAME, // Required by VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME
    volk.c.VK_KHR_CREATE_RENDERPASS_2_EXTENSION_NAME, // Required by VK_KHR_DEPTH_STENCIL_RESOLVE_EXTENSION_NAME
    volk.c.VK_KHR_MULTIVIEW_EXTENSION_NAME, // Required by VK_KHR_CREATE_RENDERPASS_2_EXTENSION_NAME
    //************************************************************************/
    // Nsight Aftermath
    //************************************************************************/
    volk.c.VK_EXT_ASTC_DECODE_MODE_EXTENSION_NAME 
};

pub fn wrap_err(value: c_int) !void {
    switch (value) {
        volk.c.VK_SUCCESS => return,
        volk.c.VK_NOT_READY => return error.NotReady,
        volk.c.VK_TIMEOUT => return error.Timeout,
        volk.c.VK_EVENT_SET => return error.EventSet,
        volk.c.VK_EVENT_RESET => return error.EventReset,
        volk.c.VK_INCOMPLETE => return error.Incomplete,
        volk.c.VK_ERROR_OUT_OF_HOST_MEMORY => return error.OutOfHostMemory,
        volk.c.VK_ERROR_OUT_OF_DEVICE_MEMORY => return error.OutOfDeviceMemory,
        volk.c.VK_ERROR_INITIALIZATION_FAILED => return error.InitializationFailed,
        volk.c.VK_ERROR_DEVICE_LOST => return error.DeviceLost,
        volk.c.VK_ERROR_MEMORY_MAP_FAILED => return error.MemoryMapFailed,
        volk.c.VK_ERROR_LAYER_NOT_PRESENT => return error.LayerNotPresent,
        volk.c.VK_ERROR_EXTENSION_NOT_PRESENT => return error.ExtensionNotPresent,
        else => return error.Unknown,
    }
}


pub fn add_next(current: anytype, next: anytype) void {
    const pNext = current.pNext;
    current.pNext = next;
    next.pNext = pNext;
}

pub fn debug_utils_messenger( messageSeverity: volk.c.VkDebugUtilsMessageSeverityFlagBitsEXT ,
											 _: volk.c.VkDebugUtilsMessageTypeFlagsEXT ,
											 callbackData: [*c]const volk.c.VkDebugUtilsMessengerCallbackDataEXT,
											 _: ?*anyopaque) callconv(.c) volk.c.VkBool32
{
    
	switch( messageSeverity ) {
		volk.c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => {
		    std.debug.print("VK ERROR: {s}\n", .{std.mem.span(callbackData.*.pMessage)});
		},
		volk.c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => {
		    std.debug.print("VK WARNING: {s}\n", .{std.mem.span(callbackData.*.pMessage)});
	    },
		else => {
		    std.debug.print("VK INFO: {s}\n", .{std.mem.span(callbackData.*.pMessage)});
        }
	}
	return volk.c.VK_FALSE;
}


pub fn vk_has_extension(properties: []const volk.c.VkExtensionProperties, val: []const u8) bool {
    for (properties) |prop| {
        if (std.mem.eql(u8, std.mem.sliceTo(prop.extensionName[0..], 0), val)) {
            return true;
        }
    }
    return false;
}

