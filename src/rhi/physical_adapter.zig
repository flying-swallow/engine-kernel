const rhi = @import("rhi.zig");
const std = @import("std");
const volk = @import("volk");
const vulkan = @import("vulkan.zig");
const gpu_preset = @import("gpu_preset.zig");

pub const Vendor = enum(u8) { unknown, nvidia, amd, intel };

pub const PresetLevel = enum(u8) {
    none,
    office, // this means unsupported
    very_low, // mostly for mobile gpu
    low,
    medium,
    high,
    ultra,
};

pub const AdapterType = enum(u8) {
    other,
    cpu,
    virtual,
    integrated,
    discrete,
};

pub const PhysicalAdapter = @This();
name: [256]u8 = std.mem.zeroes([256]u8),
luid: u64 = 0,
video_memory_size: u64 = 0,
system_memory_size: u64 = 0,
device_id: u32 = 0,
vendor: Vendor = .unknown,
preset_level: PresetLevel = .none,
adapter_type: AdapterType = .other,

// Viewports
viewport_max_num: u32 = 0,
viewport_bounds_range: [2]f32 = [_]f32{ 0, 0 },

// Attachments
attachment_max_dim: u32 = 0,
attachment_layer_max_num: u32 = 0,
color_attachment_max_num: u32 = 0,

// Multi-sampling
color_sample_max_num: u8 = 0,
depth_sample_max_num: u8 = 0,
stencil_sample_max_num: u8 = 0,
zero_attachments_sample_max_num: u8 = 0,
texture_color_sample_max_num: u8 = 0,
texture_integer_sample_max_num: u8 = 0,
texture_depth_sample_max_num: u8 = 0,
texture_stencil_sample_max_num: u8 = 0,
storage_texture_sample_max_num: u8 = 0,

// Resource dimensions
texture_1d_max_dim: u16 = 0,
texture_2d_max_dim: u16 = 0,
texture_3d_max_dim: u16 = 0,
texture_array_layer_max_num: u16 = 0,
typed_buffer_max_dim: u32 = 0,

// Memory
device_upload_heap_size: u64 = 0, // ReBAR
memory_allocation_max_num: u32 = 0,
sampler_allocation_max_num: u32 = 0,
constant_buffer_max_range: u32 = 0,
storage_buffer_max_range: u32 = 0,
buffer_texture_granularity: u64 = 0,
buffer_max_size: u64 = 0,

// Memory alignment
upload_buffer_texture_row_alignment: u32 = 0,
upload_buffer_texture_slice_alignment: u32 = 0,
buffer_shader_resource_offset_alignment: u32 = 0,
constant_buffer_offset_alignment: u32 = 0,
// scratch_buffer_offset_alignment: u32, // commented out
// shader_binding_table_alignment: u32, // commented out

// Pipeline layout
pipeline_layout_descriptor_set_max_num: u32 = 0,
pipeline_layout_root_constant_max_size: u32 = 0,
pipeline_layout_root_descriptor_max_num: u32 = 0,

// Descriptor set
descriptor_set_sampler_max_num: u32 = 0,
descriptor_set_constant_buffer_max_num: u32 = 0,
descriptor_set_storage_buffer_max_num: u32 = 0,
descriptor_set_texture_max_num: u32 = 0,
descriptor_set_storage_texture_max_num: u32 = 0,

// Shader resources
per_stage_descriptor_sampler_max_num: u32 = 0,
per_stage_descriptor_constant_buffer_max_num: u32 = 0,
per_stage_descriptor_storage_buffer_max_num: u32 = 0,
per_stage_descriptor_texture_max_num: u32 = 0,
per_stage_descriptor_storage_texture_max_num: u32 = 0,
per_stage_resource_max_num: u32 = 0,

// Vertex shader
vertex_shader_attribute_max_num: u32 = 0,
vertex_shader_stream_max_num: u32 = 0,
vertex_shader_output_component_max_num: u32 = 0,

// Tessellation shaders
tess_control_shader_generation_max_level: u32 = 0,
tess_control_shader_patch_point_max_num: u32 = 0,
tess_control_shader_per_vertex_input_component_max_num: u32 = 0,
tess_control_shader_per_vertex_output_component_max_num: u32 = 0,
tess_control_shader_per_patch_output_component_max_num: u32 = 0,
tess_control_shader_total_output_component_max_num: u32 = 0,
tess_evaluation_shader_input_component_max_num: u32 = 0,
tess_evaluation_shader_output_component_max_num: u32 = 0,

// Geometry shader
geometry_shader_invocation_max_num: u32 = 0,
geometry_shader_input_component_max_num: u32 = 0,
geometry_shader_output_component_max_num: u32 = 0,
geometry_shader_output_vertex_max_num: u32 = 0,
geometry_shader_total_output_component_max_num: u32 = 0,

// Fragment shader
fragment_shader_input_component_max_num: u32 = 0,
fragment_shader_output_attachment_max_num: u32 = 0,
fragment_shader_dual_source_attachment_max_num: u32 = 0,

// Compute shader
compute_shader_shared_memory_max_size: u32 = 0,
compute_shader_work_group_max_num: [3]u32 = [_]u32{ 0, 0, 0 },
compute_shader_work_group_invocation_max_num: u32 = 0,
compute_shader_work_group_max_dim: [3]u32 = [_]u32{ 0, 0, 0 },

// Precision bits
viewport_precision_bits: u32 = 0,
sub_pixel_precision_bits: u32 = 0,
sub_texel_precision_bits: u32 = 0,
mipmap_precision_bits: u32 = 0,

// Other
timestamp_frequency_hz: u64 = 0,
draw_indirect_max_num: u32 = 0,
sampler_lod_bias_min: f32 = 0,
sampler_lod_bias_max: f32 = 0,
sampler_anisotropy_max: f32 = 0,
texel_offset_min: i32 = 0,
texel_offset_max: u32 = 0,
texel_gather_offset_min: i32 = 0,
texel_gather_offset_max: u32 = 0,
clip_distance_max_num: u32 = 0,
cull_distance_max_num: u32 = 0,
combined_clip_and_cull_distance_max_num: u32 = 0,
// shading_rate_attachment_tile_size: u8, // commented out
// shader_model: u8, // commented out

// Tiers
// conservative_raster_tier: u8, // commented out
// sample_locations_tier: u8, // commented out
// ray_tracing_tier: u8, // commented out
// shading_rate_tier: u8, // commented out
bindless_tier: u8 = 0,

// Features (bitfields replaced with bool)
is_texture_filter_min_max_supported: bool = false,
is_logic_func_supported: bool = false,
is_depth_bounds_test_supported: bool = false,
is_draw_indirect_count_supported: bool = false,
is_independent_front_and_back_stencil_reference_and_masks_supported: bool = false,
is_copy_queue_timestamp_supported: bool = false,
is_enchanced_barrier_supported: bool = false,
is_memory_tier2_supported: bool = false,
is_dynamic_depth_bias_supported: bool = false,
is_viewport_origin_bottom_left_supported: bool = false,
is_region_resolve_supported: bool = false,

// Shader features
is_shader_native_i16_supported: bool = false,
is_shader_native_f16_supported: bool = false,
is_shader_native_i32_supported: bool = false,
is_shader_native_f32_supported: bool = false,
is_shader_native_i64_supported: bool = false,
is_shader_native_f64_supported: bool = false,
is_shader_atomics_i16_supported: bool = false,
is_shader_atomics_i32_supported: bool = false,
is_shader_atomics_i64_supported: bool = false,

// Emulated features
is_draw_parameters_emulation_enabled: bool = false,

// API-specific fields
target: union(rhi.Backend) {
    vk: rhi.wrapper_platform_type(.vk, struct {
        physical_device: volk.c.VkPhysicalDevice = std.mem.zeroes(volk.c.VkPhysicalDevice),
        api_version: u32 = 0,
        is_swap_chain_supported: bool = false,
        is_buffer_device_address_supported: bool = false,
        is_amd_device_coherent_memory_supported: bool = false,
        is_present_id_supported: bool = false,
        is_maintenance5_supported: bool = false,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
} = undefined,


pub fn enumerate_adapters(allocator: std.mem.Allocator, renderer: *rhi.Renderer) !std.ArrayList(PhysicalAdapter) {
    var result = std.ArrayList(PhysicalAdapter).empty;
    errdefer result.deinit(allocator);
    if (rhi.is_target_selected(.vk, renderer)) {
        var deviceGroupsCount: u32 = 0;
        try vulkan.wrap_err(volk.c.vkEnumeratePhysicalDeviceGroups.?(renderer.backend.vk.instance, &deviceGroupsCount, null));
        const physicalDeviceProperties = try allocator.alloc(volk.c.VkPhysicalDeviceGroupProperties, deviceGroupsCount);
        defer allocator.free(physicalDeviceProperties);
        try vulkan.wrap_err(volk.c.vkEnumeratePhysicalDeviceGroups.?(renderer.backend.vk.instance, &deviceGroupsCount, physicalDeviceProperties.ptr));
        var i: usize = 0;
        while (i < deviceGroupsCount) : (i += 1) {
            const physical_device = physicalDeviceProperties[i].physicalDevices[0];
            var extension_num: u32 = 0;
            try vulkan.wrap_err(volk.c.vkEnumerateDeviceExtensionProperties.?(physical_device, null, &extension_num, null));
            const extension_properties: []volk.c.VkExtensionProperties = try allocator.alloc(volk.c.VkExtensionProperties, extension_num);
            defer allocator.free(extension_properties);
            try vulkan.wrap_err(volk.c.vkEnumerateDeviceExtensionProperties.?(physical_device, null, &extension_num, extension_properties.ptr));

            var properties: volk.c.VkPhysicalDeviceProperties2 = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2 };
            var props11: volk.c.VkPhysicalDeviceVulkan11Properties = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_PROPERTIES };
            var props12: volk.c.VkPhysicalDeviceVulkan12Properties = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_PROPERTIES };
            var props13: volk.c.VkPhysicalDeviceVulkan13Properties = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_PROPERTIES };
            var deviceIDProperties: volk.c.VkPhysicalDeviceIDProperties = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ID_PROPERTIES };

            vulkan.add_next(&properties, &props11);
            vulkan.add_next(&properties, &props12);
            vulkan.add_next(&properties, &props13);
            vulkan.add_next(&properties, &deviceIDProperties);

            var features: volk.c.VkPhysicalDeviceFeatures2 = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2 };
            var features11: volk.c.VkPhysicalDeviceVulkan11Features = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES };
            var features12: volk.c.VkPhysicalDeviceVulkan12Features = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES };
            var features13: volk.c.VkPhysicalDeviceVulkan13Features = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES };
            var present_id_features: volk.c.VkPhysicalDevicePresentIdFeaturesKHR = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PRESENT_ID_FEATURES_KHR };

            vulkan.add_next(&features, &features11);
            vulkan.add_next(&features, &features12);
            vulkan.add_next(&features, &features13);

            if (vulkan.vk_has_extension(extension_properties, volk.c.VK_KHR_PRESENT_ID_EXTENSION_NAME)) {
                vulkan.add_next(&features, &present_id_features);
            }

            var memory_properties: volk.c.VkPhysicalDeviceMemoryProperties = .{};
            volk.c.vkGetPhysicalDeviceMemoryProperties.?(physical_device, &memory_properties);
            volk.c.vkGetPhysicalDeviceProperties2.?(physical_device, &properties);
            volk.c.vkGetPhysicalDeviceFeatures2.?(physical_device, &features);

            const limits = &properties.properties.limits;
            var physical_adapter: PhysicalAdapter = .{
                .luid = std.mem.readInt(u64, deviceIDProperties.deviceLUID[0..], .little),
                .device_id = properties.properties.deviceID,
                .vendor = switch (properties.properties.vendorID) {
                    0x10DE => .nvidia,
                    0x1002 => .amd,
                    0x8086 => .intel,
                    else => .unknown,
                },
                .target = .{ .vk = .{ 
                        .api_version = properties.properties.apiVersion, 
                        .physical_device = physicalDeviceProperties[i].physicalDevices[0], 
                        .is_present_id_supported = present_id_features.presentId > 0, 
                        .is_swap_chain_supported = vulkan.vk_has_extension(extension_properties, volk.c.VK_KHR_SWAPCHAIN_EXTENSION_NAME), 
                        .is_buffer_device_address_supported = properties.properties.apiVersion >= volk.c.VK_API_VERSION_1_2 or vulkan.vk_has_extension(extension_properties, volk.c.VK_KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME), 
                        .is_amd_device_coherent_memory_supported = vulkan.vk_has_extension(extension_properties, volk.c.VK_AMD_DEVICE_COHERENT_MEMORY_EXTENSION_NAME), 
                        .is_maintenance5_supported =  vulkan.vk_has_extension(extension_properties, volk.c.VK_KHR_MAINTENANCE_5_EXTENSION_NAME), 
                    } 
                },
                .preset_level = blk: {
                    for (gpu_preset.desktop_presets) |preset| {
                        if (preset.vendor_id == properties.properties.vendorID and preset.model_id == properties.properties.deviceID) {
                            break :blk preset.preset_level;
                        }
                    }
                    break :blk .none;
                },
                .adapter_type = switch (properties.properties.deviceType) {
                    volk.c.VK_PHYSICAL_DEVICE_TYPE_OTHER => .other,
                    volk.c.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => .integrated,
                    volk.c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => .discrete,
                    volk.c.VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU => .virtual,
                    volk.c.VK_PHYSICAL_DEVICE_TYPE_CPU => .cpu,
                    else => .other,
                },
                .viewport_max_num = limits.maxViewports,
                .viewport_bounds_range = [_]f32{ limits.viewportBoundsRange[0], limits.viewportBoundsRange[1] },

                .attachment_max_dim = @min(limits.maxFramebufferWidth, limits.maxFramebufferHeight),
                .attachment_layer_max_num = limits.maxFramebufferLayers,
                .color_attachment_max_num = limits.maxColorAttachments,

                .color_sample_max_num = @intCast(limits.framebufferColorSampleCounts),
                .depth_sample_max_num = @intCast(limits.framebufferDepthSampleCounts),
                .stencil_sample_max_num = @intCast(limits.framebufferStencilSampleCounts),
                .zero_attachments_sample_max_num = @intCast(limits.framebufferNoAttachmentsSampleCounts),
                .texture_color_sample_max_num = @intCast(limits.sampledImageColorSampleCounts),
                .texture_integer_sample_max_num = @intCast(limits.sampledImageIntegerSampleCounts),
                .texture_depth_sample_max_num = @intCast(limits.sampledImageDepthSampleCounts),
                .texture_stencil_sample_max_num = @intCast(limits.sampledImageStencilSampleCounts),
                .storage_texture_sample_max_num = @intCast(limits.storageImageSampleCounts),

                .texture_1d_max_dim = @intCast(limits.maxImageDimension1D),
                .texture_2d_max_dim = @intCast(limits.maxImageDimension2D),
                .texture_3d_max_dim = @intCast(limits.maxImageDimension3D),
                .texture_array_layer_max_num = @intCast(limits.maxImageArrayLayers),
                .typed_buffer_max_dim = limits.maxTexelBufferElements,
                .memory_allocation_max_num = limits.maxMemoryAllocationCount,
                .sampler_allocation_max_num = limits.maxSamplerAllocationCount,
                .constant_buffer_max_range = limits.maxUniformBufferRange,
                .storage_buffer_max_range = limits.maxStorageBufferRange,
                .buffer_texture_granularity = limits.bufferImageGranularity,
                .buffer_max_size = props13.maxBufferSize,

                .upload_buffer_texture_row_alignment = @intCast(limits.optimalBufferCopyRowPitchAlignment),
                .upload_buffer_texture_slice_alignment = @intCast(limits.optimalBufferCopyOffsetAlignment), // TODO: ?
                .buffer_shader_resource_offset_alignment = @intCast(@max(limits.minTexelBufferOffsetAlignment, limits.minStorageBufferOffsetAlignment)),
                .constant_buffer_offset_alignment = @intCast(limits.minUniformBufferOffsetAlignment),
                // physicalAdapter->scratchBufferOffsetAlignment = accelerationStructureProps.minAccelerationStructureScratchOffsetAlignment;
                // physicalAdapter->shaderBindingTableAlignment = rayTracingProps.shaderGroupBaseAlignment;

                .pipeline_layout_descriptor_set_max_num = limits.maxBoundDescriptorSets,
                .pipeline_layout_root_constant_max_size = limits.maxPushConstantsSize,
                // physicalAdapter->pipelineLayoutRootDescriptorMaxNum = pushDescriptorProps.maxPushDescriptors;

                .per_stage_descriptor_sampler_max_num = limits.maxPerStageDescriptorSamplers,
                .per_stage_descriptor_constant_buffer_max_num = limits.maxPerStageDescriptorUniformBuffers,
                .per_stage_descriptor_storage_buffer_max_num = limits.maxPerStageDescriptorStorageBuffers,
                .per_stage_descriptor_texture_max_num = limits.maxPerStageDescriptorSampledImages,
                .per_stage_descriptor_storage_texture_max_num = limits.maxPerStageDescriptorStorageImages,
                .per_stage_resource_max_num = limits.maxPerStageResources,

                .descriptor_set_sampler_max_num = limits.maxDescriptorSetSamplers,
                .descriptor_set_constant_buffer_max_num = limits.maxDescriptorSetUniformBuffers,
                .descriptor_set_storage_buffer_max_num = limits.maxDescriptorSetStorageBuffers,
                .descriptor_set_texture_max_num = limits.maxDescriptorSetSampledImages,
                .descriptor_set_storage_texture_max_num = limits.maxDescriptorSetStorageImages,

                .vertex_shader_attribute_max_num = limits.maxVertexInputAttributes,
                .vertex_shader_stream_max_num = limits.maxVertexInputBindings,
                .vertex_shader_output_component_max_num = limits.maxVertexOutputComponents,

                .tess_control_shader_generation_max_level = limits.maxTessellationGenerationLevel,
                .tess_control_shader_patch_point_max_num = limits.maxTessellationPatchSize,
                .tess_control_shader_per_vertex_input_component_max_num = limits.maxTessellationControlPerVertexInputComponents,
                .tess_control_shader_per_vertex_output_component_max_num = limits.maxTessellationControlPerVertexOutputComponents,
                .tess_control_shader_per_patch_output_component_max_num = limits.maxTessellationControlPerPatchOutputComponents,
                .tess_control_shader_total_output_component_max_num = limits.maxTessellationControlTotalOutputComponents,
                .tess_evaluation_shader_input_component_max_num = limits.maxTessellationEvaluationInputComponents,
                .tess_evaluation_shader_output_component_max_num = limits.maxTessellationEvaluationOutputComponents,

                .geometry_shader_invocation_max_num = limits.maxGeometryShaderInvocations,
                .geometry_shader_input_component_max_num = limits.maxGeometryInputComponents,
                .geometry_shader_output_component_max_num = limits.maxGeometryOutputComponents,
                .geometry_shader_output_vertex_max_num = limits.maxGeometryOutputVertices,
                .geometry_shader_total_output_component_max_num = limits.maxGeometryTotalOutputComponents,

                .fragment_shader_input_component_max_num = limits.maxFragmentInputComponents,
                .fragment_shader_output_attachment_max_num = limits.maxFragmentOutputAttachments,
                .fragment_shader_dual_source_attachment_max_num = limits.maxFragmentDualSrcAttachments,

                .compute_shader_shared_memory_max_size = limits.maxComputeSharedMemorySize,
                .compute_shader_work_group_max_num = [_]u32{ limits.maxComputeWorkGroupCount[0], limits.maxComputeWorkGroupCount[1], limits.maxComputeWorkGroupCount[2] },
                .compute_shader_work_group_invocation_max_num = limits.maxComputeWorkGroupInvocations,
                .compute_shader_work_group_max_dim = [_]u32{ limits.maxComputeWorkGroupSize[0], limits.maxComputeWorkGroupSize[1], limits.maxComputeWorkGroupSize[2] },

                .viewport_precision_bits = limits.viewportSubPixelBits,
                .sub_pixel_precision_bits = limits.subPixelPrecisionBits,
                .sub_texel_precision_bits = limits.subTexelPrecisionBits,
                .mipmap_precision_bits = limits.mipmapPrecisionBits,

                .timestamp_frequency_hz = @intFromFloat(1e9 / @as(f64, limits.timestampPeriod) + 0.5),
                .draw_indirect_max_num = limits.maxDrawIndirectCount,
                .sampler_lod_bias_min = -limits.maxSamplerLodBias,
                .sampler_lod_bias_max = limits.maxSamplerLodBias,
                .sampler_anisotropy_max = limits.maxSamplerAnisotropy,
                .texel_offset_min = limits.minTexelOffset,
                .texel_offset_max = limits.maxTexelOffset,
                .texel_gather_offset_min = limits.minTexelGatherOffset,
                .texel_gather_offset_max = limits.maxTexelGatherOffset,
                .clip_distance_max_num = limits.maxClipDistances,
                .cull_distance_max_num = limits.maxCullDistances,
                .combined_clip_and_cull_distance_max_num = limits.maxCombinedClipAndCullDistances,

                //physicalAdapter->vendor = VendorFromID( properties.properties.vendorID );
                //physicalAdapter->vk.physicalDevice = physicalAdapter->vk.physicalDevice;
                //physicalAdapter->vk.apiVersion = properties.properties.apiVersion;
                //physicalAdapter->presetLevel = RI_GPU_PRESET_NONE;

                .bindless_tier = if (features12.descriptorIndexing > 0) 1 else 0,

                .is_texture_filter_min_max_supported = features12.samplerFilterMinmax == volk.c.VK_TRUE,
                .is_logic_func_supported = features.features.logicOp == volk.c.VK_TRUE,
                .is_depth_bounds_test_supported = features.features.depthBounds == volk.c.VK_TRUE,
                .is_draw_indirect_count_supported = features12.drawIndirectCount == volk.c.VK_TRUE,
                .is_independent_front_and_back_stencil_reference_and_masks_supported = true,
                // physicalAdapter->isLineSmoothingSupported = lineRasterizationFeatures.smoothLines;
                .is_copy_queue_timestamp_supported = limits.timestampComputeAndGraphics == volk.c.VK_TRUE,
                // physicalAdapter->isMeshShaderPipelineStatsSupported = meshShaderFeatures.meshShaderQueries == VK_TRUE;
                .is_enchanced_barrier_supported = true,
                .is_memory_tier2_supported = true, // TODO: seems to be the best match
                .is_dynamic_depth_bias_supported = true,
                .is_viewport_origin_bottom_left_supported = true,
                .is_region_resolve_supported = true,

                .is_shader_native_i16_supported = features.features.shaderInt16 == volk.c.VK_TRUE,
                .is_shader_native_f16_supported = features12.shaderFloat16 == volk.c.VK_TRUE,
                .is_shader_native_i32_supported = true,
                .is_shader_native_f32_supported = true,
                .is_shader_native_i64_supported = features.features.shaderInt64 == volk.c.VK_TRUE,
                .is_shader_native_f64_supported = features.features.shaderFloat64 == volk.c.VK_TRUE,
                // physicalAdapter->isShaderAtomicsF16Supported = (shaderAtomicFloat2Features.shaderBufferFloat16Atomics || shaderAtomicFloat2Features.shaderSharedFloat16Atomics) ? true : false;
                .is_shader_atomics_i32_supported = true,
                // physicalAdapter->isShaderAtomicsF32Supported = (shaderAtomicFloatFeatures.shaderBufferFloat32Atomics || shaderAtomicFloatFeatures.shaderSharedFloat32Atomics) ? true : false;
                .is_shader_atomics_i64_supported = if ((features12.shaderBufferInt64Atomics == volk.c.VK_TRUE) or (features12.shaderSharedInt64Atomics == volk.c.VK_TRUE)) true else false,
                // physicalAdapter->isShaderAtomicsF64Supported = (shaderAtomicFloatFeatures.shaderBufferFloat64Atomics || shaderAtomicFloatFeatures.shaderSharedFloat64Atomics) ? true : false;
                //
                //
            };
            {
                var k: usize = 0;
                while (k < memory_properties.memoryHeapCount) : (k += 1) {
                    if ((memory_properties.memoryHeaps[i].flags & volk.c.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) != 0 and physical_adapter.adapter_type != .integrated) {
                        physical_adapter.video_memory_size += memory_properties.memoryHeaps[i].size;
                    } else {
                        physical_adapter.system_memory_size += memory_properties.memoryHeaps[i].size;
                    }
                    const uploadHeapFlags: u32 = (volk.c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT | volk.c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
                    if ((memory_properties.memoryHeaps[i].flags & uploadHeapFlags) == uploadHeapFlags) {
                        physical_adapter.device_upload_heap_size += memory_properties.memoryHeaps[i].size;
                    }
                }
            }
            std.mem.copyForwards(u8, physical_adapter.name[0..], std.mem.sliceTo(properties.properties.deviceName[0..], 0));
            try result.append(allocator, physical_adapter);
        }
    }
    return result;
}
