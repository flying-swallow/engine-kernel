const rhi = @import("rhi.zig");
const volk = @import("volk");
const vulkan = @import("vulkan.zig");
const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin"); 

pub const Renderer = @This();
backend: union(rhi.Backend) { 
    vk: rhi.wrapper_platform_type(.vk, struct { 
        api_version: u32, 
        instance: volk.c.VkInstance, 
        debug_message_utils: volk.c.VkDebugUtilsMessengerEXT 
    }), 
    dx12: rhi.wrapper_platform_type(.dx12, struct {}), 
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
},

pub fn deinit(renderer: *Renderer) void {
    switch (renderer.backend) {
        .vk => |vk| {
            if (vk.debug_message_utils != null and volk.c.vkDestroyDebugUtilsMessengerEXT != null) {
                volk.c.vkDestroyDebugUtilsMessengerEXT.?(vk.instance, vk.debug_message_utils, null);
            }
            if (vk.instance != null) {
                volk.c.vkDestroyInstance.?(vk.instance, null);
            }
        },
        .dx12 => {},
        .mtl => {},
    }
    volk.c.volkFinalize();
}

pub fn init(alloc: std.mem.Allocator, impl: union(rhi.Backend) {
    vk: struct { app_name: [*c]const u8, enable_validation_layer: bool },
    dx12: struct {},
    mtl: struct {},
}) !Renderer {
    switch (impl) {
        .vk => |opt| {
            try vulkan.wrap_err(volk.c.volkInitialize());

            var app_info: volk.c.VkApplicationInfo = .{ .sType = volk.c.VK_STRUCTURE_TYPE_APPLICATION_INFO };
            app_info.pNext = null;
            app_info.pApplicationName = opt.app_name;
            app_info.applicationVersion = volk.c.VK_MAKE_API_VERSION(1, 0, 0, 0);
            app_info.engineVersion = volk.c.VK_MAKE_API_VERSION(1, 0, 0, 0);
            app_info.apiVersion = volk.c.VK_API_VERSION_1_3;

            var validationFeatures = volk.c.VkValidationFeaturesEXT{ .sType = volk.c.VK_STRUCTURE_TYPE_VALIDATION_FEATURES_EXT };
            const enabledValidationFeatures = [_]volk.c.VkValidationFeatureEnableEXT{volk.c.VK_VALIDATION_FEATURE_ENABLE_DEBUG_PRINTF_EXT};
            validationFeatures.enabledValidationFeatureCount = enabledValidationFeatures.len;
            validationFeatures.pEnabledValidationFeatures = &enabledValidationFeatures;

            var instanceCreateInfo = volk.c.VkInstanceCreateInfo{ .sType = volk.c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO };
            instanceCreateInfo.pApplicationInfo = &app_info;
            
            var enabled_layer_names = std.ArrayList([*c]const u8).empty;
            defer enabled_layer_names.deinit(alloc);
            var enabled_extension_names = std.ArrayList([*c]const u8).empty;
            defer enabled_extension_names.deinit(alloc);

            var layerProperties: ?[]volk.c.VkLayerProperties = null;
            defer if (layerProperties) |lp| alloc.free(lp);
            var extProperties: ?[]volk.c.VkExtensionProperties = null;
            defer if (extProperties) |ep| alloc.free(ep);
            {
                var instanceLayers: u32 = 0;
                try vulkan.wrap_err(volk.c.vkEnumerateInstanceLayerProperties.?(&instanceLayers, null));
                layerProperties = try alloc.alloc(volk.c.VkLayerProperties, instanceLayers);
                try vulkan.wrap_err(volk.c.vkEnumerateInstanceLayerProperties.?(&instanceLayers, layerProperties.?.ptr));

                var i: usize = 0;
                while (i < instanceLayers) : (i += 1) {
                    var useLayer: bool = false;
                    const instanceLayerSlice = std.mem.sliceTo(layerProperties.?[i].layerName[0..], 0);
                    std.debug.print("Instance Layer: {s}({d}): {s}\n", .{instanceLayerSlice, layerProperties.?[i].specVersion, if(useLayer) "ENABLED" else "DISABLED"});
                    useLayer |= (opt.enable_validation_layer and std.mem.eql(u8, instanceLayerSlice, "VK_LAYER_KHRONOS_validation"));
                    //if (opt.filterLayers.len > 0) {
                    //    useLayer |= std.mem.indexOf(u8, opt.filterLayers, layerProperties.?[i].layerName) != null;
                    //}
                    if (useLayer) {
                        try enabled_layer_names.append(alloc, layerProperties.?[i].layerName[0..].ptr);
                    }
                }
            }
            {
                var extensionNum: u32 = 0;
                try vulkan.wrap_err(volk.c.vkEnumerateInstanceExtensionProperties.?(null, &extensionNum, null));
                extProperties = try alloc.alloc(volk.c.VkExtensionProperties, extensionNum);
                try vulkan.wrap_err(volk.c.vkEnumerateInstanceExtensionProperties.?(null, &extensionNum, &extProperties.?[0]));

                var i: usize = 0;
                while (i < extensionNum) : (i += 1) {
                    var useExtension: bool = false;
                    const extensionSlice = std.mem.sliceTo(extProperties.?[i].extensionName[0..], 0);
                    // Use platform-specific surface extensions
                    // Note: volk does not define these platform macros, so we use Zig's built-in OS detection
                    if (builtin.os.tag == .windows) {
                        useExtension |= std.mem.eql(u8, extensionSlice, volk.c.VK_KHR_WIN32_SURFACE_EXTENSION_NAME);
                    } else if (builtin.os.tag == .linux) {
                        useExtension |= std.mem.eql(u8, extensionSlice, volk.c.VK_KHR_XLIB_SURFACE_EXTENSION_NAME) or
                            std.mem.eql(u8, extensionSlice, volk.c.VK_KHR_WAYLAND_SURFACE_EXTENSION_NAME);
                    } else if (builtin.os.tag == .macos) {
                        useExtension |= std.mem.eql(u8, extensionSlice, volk.c.VK_EXT_METAL_SURFACE_EXTENSION_NAME);
                    }
                    useExtension |= std.mem.eql(u8, extensionSlice, volk.c.VK_KHR_SURFACE_EXTENSION_NAME);
                    useExtension |= std.mem.eql(u8, extensionSlice, volk.c.VK_EXT_SWAPCHAIN_COLOR_SPACE_EXTENSION_NAME);
                    useExtension |= std.mem.eql(u8, extensionSlice, volk.c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
                    std.debug.print("Instance Extension: {s}({d}): {s}\n", .{extensionSlice, extProperties.?[i].specVersion, if(useExtension) "ENABLED" else "DISABLED"});
                    if (useExtension) {
                        try enabled_extension_names.append(alloc, extProperties.?[i].extensionName[0..].ptr);
                    }
                }
            }
            instanceCreateInfo.ppEnabledLayerNames = enabled_layer_names.items.ptr;
            instanceCreateInfo.enabledLayerCount = @intCast(enabled_layer_names.items.len);
            instanceCreateInfo.ppEnabledExtensionNames = enabled_extension_names.items.ptr;
            instanceCreateInfo.enabledExtensionCount = @intCast(enabled_extension_names.items.len);

            if(impl.vk.enable_validation_layer) {
                vulkan.add_next(&instanceCreateInfo, &validationFeatures);
            }
            var instance: volk.c.VkInstance = undefined;
            try vulkan.wrap_err(volk.c.vkCreateInstance.?(&instanceCreateInfo, null, &instance));
            volk.c.volkLoadInstance(instance);
            var debug_message_util: volk.c.VkDebugUtilsMessengerEXT = null;
            if(impl.vk.enable_validation_layer and volk.c.vkCreateDebugUtilsMessengerEXT != null) {
                var debug_create_info = volk.c.VkDebugUtilsMessengerCreateInfoEXT{ .sType = volk.c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT };
                debug_create_info.pfnUserCallback = &vulkan.debug_utils_messenger;
                debug_create_info.pUserData = null;
                debug_create_info.messageSeverity = volk.c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | 
                                                  volk.c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT |
                                                  volk.c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | 
                                                  volk.c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
                debug_create_info.messageType = 
                    volk.c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | 
                    volk.c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | 
                    volk.c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;

                try vulkan.wrap_err(volk.c.vkCreateDebugUtilsMessengerEXT.?(instance, &debug_create_info, null, &debug_message_util));
            }

            return Renderer{ 
                .backend = .{ 
                    .vk = .{
                        .api_version = app_info.apiVersion,
                        .instance = instance,
                        .debug_message_utils = debug_message_util,
                    } 
                } 
            };
        },
        .dx12 => {
            if (rhi.platform_has_api(.dx12)) {
                return Renderer{ .backend = .{ .dx12 = {} } };
            }
            return error.DirectX12NotSupported;
            //@panic("DirectX 12 target not supported in this build configuration");
        },
        .mtl => {
            if (rhi.platform_has_api(.mtl)) {
                return Renderer{ .backend = .{ .mtl = {} } };
            }
            return error.MetalNotSupported;
        },
    }
}
