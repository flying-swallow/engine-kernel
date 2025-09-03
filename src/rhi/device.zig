const rhi = @import("rhi.zig");
const volk = @import("volk");
const vma = @import("vma");
const std = @import("std");
const vulkan = @import("vulkan.zig");

pub const Device = @This();

graphics_queues: rhi.Queue,
compute_queue: ?rhi.Queue,
transfer_queue: ?rhi.Queue,
adapter: rhi.PhysicalAdapter,
backend: union(rhi.Backend) {
    vk: rhi.wrapper_platform_type(.vk, struct {
        maintenance_5_feature_enabled: bool,
        conservative_raster_tier: bool,
        swapchain_mutable_format: bool,
        memory_budget: bool,
        device: volk.c.VkDevice,
        vma_allocator: vma.c.VmaAllocation,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
} = undefined,

fn supports_extension(extensions: [][:0]const u8, value: []const u8) bool {
    for (extensions) |ext| {
        if (std.mem.eql(u8, ext, value)) {
            return true;
        }
    }
    return false;
}

pub fn init(allocator: std.mem.Allocator, renderer: *rhi.Renderer, adapter: *rhi.PhysicalAdapter) !Device {
    if (rhi.is_target_selected(.vk, renderer)) {
        var extension_num: u32 = 0;
        try vulkan.wrap_err(volk.c.vkEnumerateDeviceExtensionProperties.?(adapter.backend.vk.physical_device, null, &extension_num, null));
        const extension_properties: []volk.c.VkExtensionProperties = try allocator.alloc(volk.c.VkExtensionProperties, extension_num);
        defer allocator.free(extension_properties);
        try vulkan.wrap_err(volk.c.vkEnumerateDeviceExtensionProperties.?(adapter.backend.vk.physical_device, null, &extension_num, extension_properties.ptr));
        var enabled_extension_names = std.ArrayList([:0]const u8).empty;
        defer enabled_extension_names.deinit(allocator);

        for (vulkan.default_device_extensions) |default_ext| {
            if (vulkan.vk_has_extension(extension_properties, default_ext)) {
                try enabled_extension_names.append(allocator, default_ext);
            }
        }

        const queue_family_props = ret_props: {
            var familyNum: u32 = 0;
            volk.c.vkGetPhysicalDeviceQueueFamilyProperties.?(adapter.backend.vk.physical_device, &familyNum, null);
            const res: []volk.c.VkQueueFamilyProperties = try allocator.alloc(volk.c.VkQueueFamilyProperties, familyNum);
            volk.c.vkGetPhysicalDeviceQueueFamilyProperties.?(adapter.backend.vk.physical_device, &familyNum, res.ptr);
            break :ret_props res;
        };
        defer allocator.free(queue_family_props);

        var device_queue_create_info = std.ArrayList(volk.c.VkDeviceQueueCreateInfo).empty;
        defer device_queue_create_info.deinit(allocator);
        const priorities = [_]f32{ 1.0, 0.9, 0.8, 0.7, 0.6, 0.5 };
        {
            var queue_buf: [16][]const u8 = undefined;
            var queue_feature = std.ArrayList([]const u8).initBuffer(&queue_buf);
            var i: usize = 0;
            while (i < queue_family_props.len) : (i += 1) {
                if ((queue_family_props[i].queueFlags & volk.c.VK_QUEUE_GRAPHICS_BIT) > 0)
                    queue_feature.appendAssumeCapacity("VK_QUEUE_GRAPHICS_BIT");
                if ((queue_family_props[i].queueFlags & volk.c.VK_QUEUE_COMPUTE_BIT) > 0)
                    queue_feature.appendAssumeCapacity("VK_QUEUE_COMPUTE_BIT");
                if ((queue_family_props[i].queueFlags & volk.c.VK_QUEUE_TRANSFER_BIT) > 0)
                    queue_feature.appendAssumeCapacity("VK_QUEUE_TRANSFER_BIT");
                if ((queue_family_props[i].queueFlags & volk.c.VK_QUEUE_SPARSE_BINDING_BIT) > 0)
                    queue_feature.appendAssumeCapacity("VK_QUEUE_SPARSE_BINDING_BIT");
                if ((queue_family_props[i].queueFlags & volk.c.VK_QUEUE_PROTECTED_BIT) > 0)
                    queue_feature.appendAssumeCapacity("VK_QUEUE_PROTECTED_BIT");
                if ((queue_family_props[i].queueFlags & volk.c.VK_QUEUE_VIDEO_DECODE_BIT_KHR) > 0)
                    queue_feature.appendAssumeCapacity("VK_QUEUE_VIDEO_DECODE_BIT_KHR");
                if ((queue_family_props[i].queueFlags & volk.c.VK_QUEUE_VIDEO_ENCODE_BIT_KHR) > 0)
                    queue_feature.appendAssumeCapacity("VK_QUEUE_VIDEO_ENCODE_BIT_KHR");
                if ((queue_family_props[i].queueFlags & volk.c.VK_QUEUE_OPTICAL_FLOW_BIT_NV) > 0)
                    queue_feature.appendAssumeCapacity("VK_QUEUE_OPTICAL_FLOW_BIT_NV");
                const features = try std.mem.join(allocator, ",", queue_feature.items);
                defer allocator.free(features);
                std.debug.print("Queue Family {d}: {s}\n", .{ i, features });
                queue_feature.clearRetainingCapacity();
            }
        }

        var rhi_queues: [3]?rhi.Queue = .{null} ** 3;
        const configured = [_]struct {
            required_bits: volk.c.VkQueueFlags,
        }{
            .{ .required_bits = volk.c.VK_QUEUE_GRAPHICS_BIT },
            .{ .required_bits = volk.c.VK_QUEUE_COMPUTE_BIT },
            .{ .required_bits = volk.c.VK_QUEUE_TRANSFER_BIT },
        };
        for (configured, 0..) |config, config_idx| {
            var min_queue_flags: u32 = std.math.maxInt(u32);
            var best_queue_family_idx: u32 = 0;
            var family_idx: u32 = 0;
            while (family_idx < queue_family_props.len) : (family_idx += 1) {

                // slot zero is the graphics queue
                if (config_idx == 0 and (config.required_bits & queue_family_props[family_idx].queueFlags) == config.required_bits) {
                    best_queue_family_idx = family_idx;
                    break;
                }
                const queue_create_info = p: {
                    for (device_queue_create_info.items) |item| {
                        if (item.queueFamilyIndex == family_idx) {
                            break :p &item;
                        }
                    }
                    break :p null;
                };
                if (queue_family_props[family_idx].queueCount == 0) {
                    continue;
                }
                const matching_queue_flags = queue_family_props[family_idx].queueFlags & config.required_bits;
                // Example: Required flag is VK_QUEUE_TRANSFER_BIT and the queue family has only VK_QUEUE_TRANSFER_BIT set
                if ((matching_queue_flags > 0) and ((queue_family_props[family_idx].queueFlags & ~config.required_bits) == 0) and
                    (queue_family_props[family_idx].queueCount - (if (queue_create_info) |c| c.queueCount else 0)) > 0)
                {
                    best_queue_family_idx = family_idx;
                    break;
                }

                // Queue family 1 has VK_QUEUE_TRANSFER_BIT | VK_QUEUE_COMPUTE_BIT
                // Queue family 2 has VK_QUEUE_TRANSFER_BIT | VK_QUEUE_COMPUTE_BIT | VK_QUEUE_SPARSE_BINDING_BIT
                // Since 1 has less flags, we choose queue family 1
                if ((matching_queue_flags > 0) and ((queue_family_props[family_idx].queueFlags - matching_queue_flags) < min_queue_flags)) {
                    best_queue_family_idx = family_idx;
                    min_queue_flags = (queue_family_props[family_idx].queueFlags - matching_queue_flags);
                }
            }

            var queue_create_info = p: {
                for (device_queue_create_info.items) |*item| {
                    if (item.queueFamilyIndex == family_idx) {
                        break :p item;
                    }
                }
                try device_queue_create_info.append(allocator, .{
                    .sType = volk.c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                    .pNext = null,
                    .flags = 0,
                    .queueFamilyIndex = best_queue_family_idx,
                    .queueCount = 0,
                    .pQueuePriorities = &priorities,
                });
                break :p &device_queue_create_info.items[device_queue_create_info.items.len - 1];
            };
            // we've run out of queues in this family, try to find a duplicate queue from other families
            if (queue_create_info.queueCount >= queue_family_props[queue_create_info.queueFamilyIndex].queueCount) {
                min_queue_flags = std.math.maxInt(u32);
                var dup_queue: ?*rhi.Queue = null;
                var i: usize = 0;
                while (i < rhi_queues.len) : (i += 1) {
                    if(rhi_queues[i]) |*eq| {
                        const matching_queue_flags: u32 = (eq.backend.vk.queue_flags & config.required_bits);
                        if ((matching_queue_flags > 0) and ((eq.backend.vk.queue_flags & ~config.required_bits) == 0)) {
                            dup_queue = eq;
                            break;
                        }

                        if ((matching_queue_flags > 0) and ((eq.backend.vk.queue_flags - matching_queue_flags) < min_queue_flags)) {
                            min_queue_flags = (eq.backend.vk.queue_flags - matching_queue_flags);
                            dup_queue = eq;
                        }

                    }
                }
                if (dup_queue) |d| {
                    rhi_queues[config_idx] = d.*;
                }
            } else {
                rhi_queues[config_idx] = rhi.Queue{
                    .backend = .{ .vk = .{
                        .queue_flags = queue_family_props[queue_create_info.queueFamilyIndex].queueFlags,
                        .family_index = queue_create_info.queueFamilyIndex,
                        .slot_index = queue_create_info.queueCount,
                        .queue = null,
                    } },
                };
                queue_create_info.queueCount += 1;
            }
        }
        const has_maintenance_5 = supports_extension(enabled_extension_names.items, volk.c.VK_KHR_MAINTENANCE_5_EXTENSION_NAME);
        var features: volk.c.VkPhysicalDeviceFeatures2 = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2 };

        var features11: volk.c.VkPhysicalDeviceVulkan11Features = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES };
        vulkan.add_next(&features, &features11);

        var features12: volk.c.VkPhysicalDeviceVulkan12Features = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES };
        vulkan.add_next(&features, &features12);

        var features13: volk.c.VkPhysicalDeviceVulkan13Features = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES };
        if (renderer.backend.vk.api_version >= volk.c.VK_API_VERSION_1_3) {
            vulkan.add_next(&features, &features13);
        }

        var maintenance5Features: volk.c.VkPhysicalDeviceMaintenance5FeaturesKHR = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MAINTENANCE_5_FEATURES_KHR };
        if (has_maintenance_5) {
            vulkan.add_next(&features, &maintenance5Features);
            //device->vk.maintenance5Features = true;
        }

        var presentIdFeatures: volk.c.VkPhysicalDevicePresentIdFeaturesKHR = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PRESENT_ID_FEATURES_KHR };
        if (supports_extension(enabled_extension_names.items, volk.c.VK_KHR_PRESENT_ID_EXTENSION_NAME)) {
            vulkan.add_next(&features, &presentIdFeatures);
        }

        var presentWaitFeatures: volk.c.VkPhysicalDevicePresentWaitFeaturesKHR = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PRESENT_WAIT_FEATURES_KHR };
        if (supports_extension(enabled_extension_names.items, volk.c.VK_KHR_PRESENT_WAIT_EXTENSION_NAME)) {
            vulkan.add_next(&features, &presentWaitFeatures);
        }

        var line_rasterization_features: volk.c.VkPhysicalDeviceLineRasterizationFeaturesKHR = .{ .sType = volk.c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_LINE_RASTERIZATION_FEATURES_KHR };
        if (supports_extension(enabled_extension_names.items, volk.c.VK_KHR_LINE_RASTERIZATION_EXTENSION_NAME)) {
            vulkan.add_next(&features, &line_rasterization_features);
        }
        volk.c.vkGetPhysicalDeviceFeatures2.?(adapter.backend.vk.physical_device, &features);
        var device_create_info: volk.c.VkDeviceCreateInfo = .{ .sType = volk.c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO };
        device_create_info.pNext = &features;
        device_create_info.pQueueCreateInfos = device_queue_create_info.items.ptr;
        device_create_info.queueCreateInfoCount = @intCast(device_queue_create_info.items.len);
        device_create_info.enabledExtensionCount = @intCast(enabled_extension_names.items.len);
        device_create_info.ppEnabledExtensionNames = @ptrCast(enabled_extension_names.items.ptr);
        var device: volk.c.VkDevice = null;
        try vulkan.wrap_err(volk.c.vkCreateDevice.?(adapter.backend.vk.physical_device, &device_create_info, null, &device));

        const vma_allocator: vma.c.VmaAllocator = p: {
            const vulkan_func: vma.c.VmaVulkanFunctions = .{
                .vkGetPhysicalDeviceProperties = @ptrCast(volk.c.vkGetPhysicalDeviceProperties),
                .vkGetInstanceProcAddr = @ptrCast(volk.c.vkGetInstanceProcAddr),
                .vkGetDeviceProcAddr = @ptrCast(volk.c.vkGetDeviceProcAddr),
                .vkGetPhysicalDeviceMemoryProperties = @ptrCast(volk.c.vkGetPhysicalDeviceMemoryProperties),
                .vkAllocateMemory = @ptrCast(volk.c.vkAllocateMemory),
                .vkFreeMemory = @ptrCast(volk.c.vkFreeMemory),
                .vkMapMemory = @ptrCast(volk.c.vkMapMemory),
                .vkUnmapMemory = @ptrCast(volk.c.vkUnmapMemory),
                .vkFlushMappedMemoryRanges = @ptrCast(volk.c.vkFlushMappedMemoryRanges),
                .vkInvalidateMappedMemoryRanges = @ptrCast(volk.c.vkInvalidateMappedMemoryRanges),
                .vkBindBufferMemory = @ptrCast(volk.c.vkBindBufferMemory),
                .vkBindImageMemory = @ptrCast(volk.c.vkBindImageMemory),
                .vkGetBufferMemoryRequirements = @ptrCast(volk.c.vkGetBufferMemoryRequirements),
                .vkGetImageMemoryRequirements = @ptrCast(volk.c.vkGetImageMemoryRequirements),
                .vkCreateBuffer = @ptrCast(volk.c.vkCreateBuffer),
                .vkDestroyBuffer = @ptrCast(volk.c.vkDestroyBuffer),
                .vkCreateImage = @ptrCast(volk.c.vkCreateImage),
                .vkDestroyImage = @ptrCast(volk.c.vkDestroyImage),
                .vkCmdCopyBuffer = @ptrCast(volk.c.vkCmdCopyBuffer),
                // Fetch "vkGetBufferMemoryRequirements2" on Vulkan >= 1.1, fetch "vkGetBufferMemoryRequirements2KHR" when using VK_KHR_dedicated_allocation extension.
                .vkGetBufferMemoryRequirements2KHR = @ptrCast(volk.c.vkGetBufferMemoryRequirements2KHR),
                // Fetch "vkGetImageMemoryRequirements2" on Vulkan >= 1.1, fetch "vkGetImageMemoryRequirements2KHR" when using VK_KHR_dedicated_allocation extension.
                .vkGetImageMemoryRequirements2KHR = @ptrCast(volk.c.vkGetImageMemoryRequirements2KHR),
                // Fetch "vkBindBufferMemory2" on Vulkan >= 1.1, fetch "vkBindBufferMemory2KHR" when using VK_KHR_bind_memory2 extension.
                .vkBindBufferMemory2KHR = @ptrCast(volk.c.vkBindBufferMemory2KHR),
                // Fetch "vkBindImageMemory2" on Vulkan >= 1.1, fetch "vkBindImageMemory2KHR" when using VK_KHR_bind_memory2 extension.
                .vkBindImageMemory2KHR = @ptrCast(volk.c.vkBindImageMemory2KHR),
                // Fetch from "vkGetPhysicalDeviceMemoryProperties2" on Vulkan >= 1.1, but you can also fetch it from "vkGetPhysicalDeviceMemoryProperties2KHR" if you enabled extension
                // VK_KHR_get_physical_device_properties2.
                .vkGetPhysicalDeviceMemoryProperties2KHR = @ptrCast(volk.c.vkGetPhysicalDeviceMemoryProperties2KHR),
                // Fetch from "vkGetDeviceBufferMemoryRequirements" on Vulkan >= 1.3, but you can also fetch it from "vkGetDeviceBufferMemoryRequirementsKHR" if you enabled extension VK_KHR_maintenance4.
                .vkGetDeviceBufferMemoryRequirements = @ptrCast(volk.c.vkGetDeviceBufferMemoryRequirements),
                // Fetch from "vkGetDeviceImageMemoryRequirements" on Vulkan >= 1.3, but you can also fetch it from "vkGetDeviceImageMemoryRequirementsKHR" if you enabled extension VK_KHR_maintenance4.
                .vkGetDeviceImageMemoryRequirements = @ptrCast(volk.c.vkGetDeviceImageMemoryRequirements),
            };

            var vma_create_info: vma.c.VmaAllocatorCreateInfo = .{ .physicalDevice = @ptrCast(adapter.backend.vk.physical_device), .device = @ptrCast(device), .flags = 
                (if (adapter.backend.vk.is_buffer_device_address_supported) @as(u32, @intCast(vma.c.VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT)) else 0) |
                (if (adapter.backend.vk.is_amd_device_coherent_memory_supported) @as(u32, @intCast(vma.c.VMA_ALLOCATOR_CREATE_AMD_DEVICE_COHERENT_MEMORY_BIT)) else 0), 
                .instance = @ptrCast(renderer.backend.vk.instance), 
                .pVulkanFunctions = &vulkan_func, 
                .vulkanApiVersion = volk.c.VK_API_VERSION_1_3 
            };
            var vma_allocator: vma.c.VmaAllocator = null;
            try vulkan.wrap_err(vma.c.vmaCreateAllocator(&vma_create_info, &vma_allocator));
            break :p vma_allocator;
        };

        return .{ .graphics_queues = 
            if (rhi_queues[0]) |q| q else return error.NoGraphicsQueue, 
            .compute_queue = rhi_queues[1], 
            .transfer_queue = rhi_queues[2], 
            .adapter = adapter.*, 
            .backend = .{ .vk = .{
                .maintenance_5_feature_enabled = has_maintenance_5,
                .conservative_raster_tier = false,
                .swapchain_mutable_format = false,
                .memory_budget = false,
                .device = device,
                .vma_allocator = @ptrCast(vma_allocator),
            } 
        } };
    }
    return error.Unitialized;
}
