pub const Swapchain = @This();
pub const rhi = @import("rhi.zig");
const builtin = @import("builtin");
const volk = @import("volk");
const vulkan = @import("vulkan.zig");

pub const SwapchainFormat = enum {
    bt709_g10_16bit, 
    bt709_g22_8bit, 
    bt709_g22_10bit, 
    bt2020_g2084_10bit 
};

pub const WindowType = if(builtin.os.tag == .windows) enum {
        windows,
} else if(builtin.os.tag == .linux) enum {
        x11,
        wayland,
} else if(builtin.os.tag == .macos or .ios) enum {
        metal
} else {
    // Unsupported platform
    @compileError("Unsupported platform for WindowType");
};

pub const WindowHandle = if(builtin.os.tag == .windows) union(WindowType) {
        windows: struct {
            hwnd: *anyopaque = null,
            hinstance: *anyopaque = null,
        },
    } else if(builtin.os.tag == .linux) union(WindowType) {
        x11: struct {
            display: *anyopaque = null,
            window: u64 = 0,
        },
        wayland: struct {
            display: *anyopaque = null,
            surface: *anyopaque = null,
            shell_surface: *anyopaque  = null,
        },
    } else if(builtin.os.tag == .macos or .ios) union(WindowType) {
        metal: struct {
            layer: *anyopaque = null,
        },
    } else {
        // Unsupported platform
        @compileError("Unsupported platform for WindowHandle");
    };

width: u16,
height: u16,
backend: union(rhi.Target) {
    vk: rhi.wrapper_platform_type(.vk, struct {
        swapchain: volk.c.VkSwapchainKHR = null,
        //images: []volk.c.VkImage = &[_]volk.c.VkImage{},
//image_views: []volk.c.VkImageView = &[_]volk.c.VkImageView{},
        format: volk.c.VkFormat = volk.c.VK_FORMAT_UNDEFINED,
        surface: volk.c.VkSurfaceKHR = null,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
},

pub fn init(renderer: *rhi.Renderer, _ : *rhi.Device, width: u16, height: u16, _: *rhi.Queue, handle: WindowHandle, _: struct {
    format: SwapchainFormat = .bt709_g22_8bit
}) Swapchain {
    const surface = if(builtin.os.tag == .windows) {

    } else if(builtin.os.tag == .linux) p: {
        switch(handle) {
            .x11 => |val| {
                var xlib_surface_create: volk.c.VkXlibSurfaceCreateInfoKHR = .{
                    .sType = volk.c.VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
                    .pNext = null,
                    .flags = 0,
                    .dpy = val.display,
                    .window = val.window,
                }; 
                var surface: volk.c.VkSurfaceKHR = undefined;
                vulkan.wrap_err(volk.c.vkCreateXlibSurfaceKHR( renderer.*.backend.vk.instance, &xlib_surface_create, null, &surface));
                break :p surface;
            },
            .wayland => {
            },
        }
    } else if(builtin.os.tag == .macos or builtin.os.tag == .ios) {
    } else {
        @compileError("Unsupported platform for Swapchain.init");
    };
    return Swapchain{ .width = width, .height = height,
        .backend = .{
            .vk = .{
                .surface = surface,
            }
        }
    };
}
