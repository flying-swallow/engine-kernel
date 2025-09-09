pub const Swapchain = @This();
pub const rhi = @import("rhi.zig");
const builtin = @import("builtin");
const volk = @import("volk");
const vulkan = @import("vulkan.zig");
const std = @import("std");

pub const SwapchainFormat = enum { bt709_g10_16bit, bt709_g22_8bit, bt709_g22_10bit, bt2020_g2084_10bit };

pub const WindowType = if (builtin.os.tag == .windows) enum {
    windows,
} else if (builtin.os.tag == .linux) enum {
    x11,
    wayland,
} else if (builtin.os.tag == .macos or .ios) enum { metal } else {
    // Unsupported platform
    @compileError("Unsupported platform for WindowType");
};

pub const WindowHandle = if (builtin.os.tag == .windows) union(WindowType) {
    windows: struct {
        hwnd: ?*anyopaque = null,
        hinstance: ?*anyopaque = null,
    },
} else if (builtin.os.tag == .linux) union(WindowType) {
    x11: struct {
        display: ?*anyopaque = null,
        window: c_ulong = 0,
    },
    wayland: struct {
        display: ?*anyopaque = null,
        surface: ?*anyopaque = null,
        shell_surface: ?*anyopaque = null,
    },
} else if (builtin.os.tag == .macos or .ios) union(WindowType) {
    metal: struct {
        layer: *anyopaque = null,
    },
} else {
    // Unsupported platform
    @compileError("Unsupported platform for WindowHandle");
};

allocator: std.mem.Allocator,
present_queue: *rhi.Queue,
width: u16,
height: u16,
backend: union(rhi.Backend) {
    vk: rhi.wrapper_platform_type(.vk, struct {
        format: volk.c.VkFormat,
        swapchain: volk.c.VkSwapchainKHR = null,
        surface: volk.c.VkSurfaceKHR = null,
        images: []volk.c.VkImage,
        views: []volk.c.VkImageView,
        signal_semaphore: volk.c.VkSemaphore,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
},

pub fn image_view(self: *Swapchain, renderer: *rhi.Renderer, index: u32) rhi.Image.ImageView{
    if (rhi.is_target_selected(.vk, renderer)) {
        return .{
            .vk = self.backend.vk.views[index],
        };
    }
    unreachable;
}

pub fn image(self: *Swapchain, renderer: *rhi.Renderer, index: u32) rhi.Image {
    if (rhi.is_target_selected(.vk, renderer)) {
        return .{
            .backend = .{
                .vk = .{
                    .image = self.backend.vk.images[index]
                },
            },
        };
    }
    unreachable;
}

fn __priority_BT709_G22_16BIT(surface: *const volk.c.VkSurfaceFormatKHR) u32 {
    return (@as(u32, @intFromBool(surface.format == volk.c.VK_FORMAT_R16G16B16A16_SFLOAT))) |
        (@as(u32, @intFromBool(surface.colorSpace == volk.c.VK_COLOR_SPACE_EXTENDED_SRGB_LINEAR_EXT)) << 1);
}

fn __priority_BT709_G22_8BIT(surface: *const volk.c.VkSurfaceFormatKHR) u32 {
    // https://registry.khronos.org/vulkan/specs/1.3-extensions/man/html/vkGetPhysicalDeviceSurfaceFormatsKHR.html
    // There is always a corresponding UNORM, SRGB just need to consider UNORM
    return (@as(u32, @intFromBool(surface.format == volk.c.VK_FORMAT_R8G8B8A8_UNORM or surface.format == volk.c.VK_FORMAT_B8G8R8A8_UNORM))) |
        (@as(u32, @intFromBool(surface.colorSpace == volk.c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)) << 1);
}

fn __priority_BT709_G22_10BIT(surface: *const volk.c.VkSurfaceFormatKHR) u32 {
    return (@as(u32, @intFromBool(surface.format == volk.c.VK_FORMAT_A2B10G10R10_UNORM_PACK32))) |
        (@as(u32, @intFromBool(surface.colorSpace == volk.c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)) << 1);
}

fn __priority_BT2020_G2084_10BIT(surface: *const volk.c.VkSurfaceFormatKHR) u32 {
    return (@as(u32, @intFromBool(surface.format == volk.c.VK_FORMAT_A2B10G10R10_UNORM_PACK32))) |
        (@as(u32, @intFromBool(surface.colorSpace == volk.c.VK_COLOR_SPACE_HDR10_ST2084_EXT)) << 1);
}

pub fn deinit(self: *Swapchain) void {
    switch (self.backend) {
        .vk => {
            //for (self.backend.vk.image_acquire_semaphores) |sem| {
            //    volk.c.vkDestroySemaphore.?(self.backend.vk.swapchain, sem, null);
            //}
            //for (self.backend.vk.finish_semaphores) |sem| {
            //    volk.c.vkDestroySemaphore.?(self.backend.vk.swapchain, sem, null);
            //}
            //volk.c.vkDestroySwapchainKHR.?(self.backend.vk.swapchain, self.backend.vk.swapchain, null);
            //volk.c.vkDestroySurfaceKHR.?(self.backend.vk.swapchain, self.backend.vk.surface, null);
            //self.allocator.free(self.backend.vk.images);
            //self.allocator.free(self.backend.vk.image_acquire_semaphores);
            //self.allocator.free(self.backend.vk.finish_semaphores);
        },
        .dx12 => {},
        .mtl => {},
    }
}

pub fn acquire_next_image(self: *Swapchain, renderer: *rhi.Renderer, device: *rhi.Device, options: struct {
    vk: ?rhi.wrapper_platform_type(.vk, struct {
        fence: volk.c.VkFence = null,
    }),
    dx12: ?rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: ?rhi.wrapper_platform_type(.mtl, struct {}),
}) !u32 {
    if (rhi.is_target_selected(.vk, renderer)) {
        std.debug.assert(options.vk != null);
        var image_index: u32 = 0;
        try vulkan.wrap_err(volk.c.vkAcquireNextImageKHR.?(device.backend.vk.device, self.backend.vk.swapchain, std.math.maxInt(u64), self.backend.vk.signal_semaphore, null, &image_index));
        return image_index;
    } else if (rhi.is_target_selected(.dx12, renderer)) {

    } else if (rhi.is_target_selected(.mtl, renderer)) {

    }
    return error.UnsupportedBackend;
}

pub fn init(allocator: std.mem.Allocator, renderer: *rhi.Renderer, device: *rhi.Device, width: u16, height: u16, queue: *rhi.Queue, handle: WindowHandle, option: struct {
    format: SwapchainFormat = .bt709_g22_8bit,
    image_count: u32 = 3,
}) !Swapchain {
    const surface: volk.c.VkSurfaceKHR = if (builtin.os.tag == .windows) {} else if (builtin.os.tag == .linux) p: {
        switch (handle) {
            .x11 => |val| {
                var xlib_surface_create: volk.c.VkXlibSurfaceCreateInfoKHR = .{
                    .sType = volk.c.VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
                    .flags = 0,
                    .dpy = @ptrCast(val.display),
                    .window = val.window,
                };
                var surface: volk.c.VkSurfaceKHR = undefined;
                try vulkan.wrap_err(volk.c.vkCreateXlibSurfaceKHR.?(renderer.*.backend.vk.instance, &xlib_surface_create, null, &surface));
                break :p surface;
            },
            .wayland => |val| {
                var wayland_surface_create: volk.c.VkWaylandSurfaceCreateInfoKHR = .{
                    .sType = volk.c.VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR,
                    .display = @ptrCast(val.display),
                    .surface = @ptrCast(val.surface),
                };
                var surface: volk.c.VkSurfaceKHR = undefined;
                try vulkan.wrap_err(volk.c.vkCreateWaylandSurfaceKHR.?(renderer.*.backend.vk.instance, &wayland_surface_create, null, &surface));
                break :p surface;
            },
        }
        return error.Unsupported;
    } else if (builtin.os.tag == .macos or builtin.os.tag == .ios) {} else {
        @compileError("Unsupported platform for Swapchain.init");
    };
    const avaliable_surface_formats = p: {
        var numSurfaceFormats: u32 = 0;
        try vulkan.wrap_err(volk.c.vkGetPhysicalDeviceSurfaceFormatsKHR.?(device.adapter.backend.vk.physical_device, surface, &numSurfaceFormats, null));
        const surface_formats = try allocator.alloc(volk.c.VkSurfaceFormatKHR, numSurfaceFormats);
        try vulkan.wrap_err(volk.c.vkGetPhysicalDeviceSurfaceFormatsKHR.?(device.adapter.backend.vk.physical_device, surface, &numSurfaceFormats, surface_formats.ptr));
        break :p surface_formats;
    };
    defer allocator.free(avaliable_surface_formats);
    var selected_surface: *const volk.c.VkSurfaceFormatKHR = &avaliable_surface_formats[0];
    const selection_fn = switch (option.format) {
        .bt709_g10_16bit => &__priority_BT709_G22_16BIT,
        .bt709_g22_8bit => &__priority_BT709_G22_8BIT,
        .bt709_g22_10bit => &__priority_BT709_G22_10BIT,
        .bt2020_g2084_10bit => &__priority_BT2020_G2084_10BIT,
    };
    for (avaliable_surface_formats) |*fmt| {
        if (selection_fn(fmt) > selection_fn(selected_surface)) {
            selected_surface = fmt;
        }
    }

    const avaliable_present_modes = p: {
        var numSurfaceFormats: u32 = 0;
        try vulkan.wrap_err(volk.c.vkGetPhysicalDeviceSurfacePresentModesKHR.?(device.adapter.backend.vk.physical_device, surface, &numSurfaceFormats, null));
        const present_modes = try allocator.alloc(volk.c.VkPresentModeKHR, numSurfaceFormats);
        try vulkan.wrap_err(volk.c.vkGetPhysicalDeviceSurfacePresentModesKHR.?(device.adapter.backend.vk.physical_device, surface, &numSurfaceFormats, present_modes.ptr));
        break :p present_modes;
    };
    defer allocator.free(avaliable_present_modes);

    // The VK_PRESENT_MODE_FIFO_KHR mode must always be present as per spec
    // This mode waits for the vertical blank ("v-sync")
    const present_mode: volk.c.VkPresentModeKHR = found: {
        const preferred_mode_list = [_]volk.c.VkPresentModeKHR{ volk.c.VK_PRESENT_MODE_IMMEDIATE_KHR, volk.c.VK_PRESENT_MODE_FIFO_RELAXED_KHR, volk.c.VK_PRESENT_MODE_FIFO_KHR };
        for (preferred_mode_list) |preferred_mode| {
            for (avaliable_present_modes) |avil| {
                if (avil == preferred_mode) {
                    break :found preferred_mode;
                }
            }
        }
        break :found volk.c.VK_PRESENT_MODE_FIFO_KHR;
    };

    var swapchain_create_info: volk.c.VkSwapchainCreateInfoKHR = .{
        .sType = volk.c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = surface,
        .minImageCount = option.image_count,
        .imageFormat = selected_surface.format,
        .imageColorSpace = selected_surface.colorSpace,
        .imageExtent = volk.c.VkExtent2D{
            .width = width,
            .height = height,
        },
        .imageArrayLayers = 1,
        .imageUsage = volk.c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | volk.c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
        .imageSharingMode = volk.c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .preTransform = volk.c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        .compositeAlpha = volk.c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = present_mode,
        .clipped = volk.c.VK_TRUE,
        .oldSwapchain = null,
        .flags = 0,
    };
    var swapchain: volk.c.VkSwapchainKHR = null;
    try vulkan.wrap_err(volk.c.vkCreateSwapchainKHR.?(device.backend.vk.device, &swapchain_create_info, null, &swapchain));

    const images = p: {
        var imageNum: u32 = 0;
        try vulkan.wrap_err(volk.c.vkGetSwapchainImagesKHR.?(device.backend.vk.device, swapchain, &imageNum, null));
        const res = try allocator.alloc(volk.c.VkImage, imageNum);
        try vulkan.wrap_err(volk.c.vkGetSwapchainImagesKHR.?(device.backend.vk.device, swapchain, &imageNum, res.ptr));
        break :p res;
    };
    errdefer allocator.free(images);

    std.debug.assert(images.len == option.image_count);
    //var semaphores_acquire = try allocator.alloc(volk.c.VkSemaphore, images.len);
    //errdefer allocator.free(semaphores_acquire);
    //var semaphores_finish = try allocator.alloc(volk.c.VkSemaphore, images.len);
    //errdefer allocator.free(semaphores_finish);
    const image_views = try allocator.alloc(volk.c.VkImageView, images.len);
    errdefer allocator.free(image_views);
    var create_info: volk.c.VkSemaphoreCreateInfo = .{ .sType = volk.c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO };
    var signal_semaphore: volk.c.VkSemaphore = null;
    try vulkan.wrap_err(volk.c.vkCreateSemaphore.?(device.backend.vk.device, &create_info, null, &signal_semaphore));

    {
        var k: usize = 0;
        while (k < images.len) : (k += 1) {
            //var timeline_create_info: volk.c.VkSemaphoreTypeCreateInfo = .{ .sType = volk.c.VK_STRUCTURE_TYPE_SEMAPHORE_TYPE_CREATE_INFO, .semaphoreType = volk.c.VK_SEMAPHORE_TYPE_BINARY };
            //vulkan.add_next(&create_info, &timeline_create_info);
            //try vulkan.wrap_err(volk.c.vkCreateSemaphore.?(device.backend.vk.device, &create_info, null, &semaphores_acquire[k]));
            //try vulkan.wrap_err(volk.c.vkCreateSemaphore.?(device.backend.vk.device, &create_info, null, &semaphores_finish[k]));

            const view_create_info: volk.c.VkImageViewCreateInfo = .{
                .sType = volk.c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = images[k],
                .viewType = volk.c.VK_IMAGE_VIEW_TYPE_2D,
                .format = selected_surface.format,
                .components = volk.c.VkComponentMapping{
                    .r = volk.c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .g = volk.c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .b = volk.c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .a = volk.c.VK_COMPONENT_SWIZZLE_IDENTITY,
                },
                .subresourceRange = volk.c.VkImageSubresourceRange{
                    .aspectMask = volk.c.VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
            };
            try vulkan.wrap_err(volk.c.vkCreateImageView.?(device.backend.vk.device, &view_create_info, null, &image_views[k]));
        }
    }

    return Swapchain{
        .allocator = allocator,
        .width = width,
        .height = height,
        .present_queue = queue,
        .backend = .{
            .vk = .{
                .format = selected_surface.format,
                .swapchain = swapchain,
                .surface = surface,
                .images = images,
                .views = image_views,
                .signal_semaphore = signal_semaphore,
            },
        },
    };
}
