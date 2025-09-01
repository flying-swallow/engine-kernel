# engine-kernel

engine-kernel is a cross-platform rendering hardware interface (RHI) abstraction layer written in Zig. It provides a platform-agnostic interface for working with various graphics APIs, focusing initially on Vulkan with planned support for DirectX 12 and Metal.

## Overview

This library serves as an abstraction layer over low-level graphics APIs, allowing developers to write graphics code that can run on multiple platforms without having to rewrite large portions of their rendering code. The primary goal is to provide a clean, efficient, and Zig-native interface to graphics hardware.

## Features

- **Cross-platform abstraction**: Support for multiple graphics backends:
  - Vulkan (implemented)
  - DirectX 12 (planned)
  - Metal (planned)
- **SDL3 integration**: Window management and platform abstraction using SDL3
- **Modern API design**: Clean Zig-native interface with error handling and resource management
- **Hardware abstraction**: Common interface for buffers, textures, pipelines, etc.
- **Format support**: Comprehensive texture format handling

## Dependencies

- [SDL3](https://github.com/libsdl-org/SDL): For window management and platform abstraction
- [volk](https://github.com/zeux/volk): Vulkan meta-loader
- [VMA (Vulkan Memory Allocator)](https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator): Memory management for Vulkan
- [zwindows](https://github.com/zig-gamedev/zwindows): Windows API bindings (for Windows support)

## Architecture

GraphicsKernel consists of several key components:

1. **Renderer**: Core abstraction over different graphics APIs
2. **PhysicalAdapter**: Represents a physical GPU device
3. **Device**: Logical device and resource creation
4. **Queue**: Command submission and execution
5. **Format**: Texture format definitions and utilities
6. **Swapchain**: Presentation surface management
7. **Texture**: Texture resource management

## Building

GraphicsKernel uses Zig's build system. To build the project:

```bash
# Clone the repository
git clone https://your-repository-url/GraphicsKernel.git
cd GraphicsKernel

# Build the project
zig build

# Run the example application
zig build run
```

## System Requirements

- Zig 0.16.0 or newer
- Vulkan-compatible GPU and drivers
- For Windows: Windows 10 or newer
- For macOS: macOS 10.15 or newer (for Metal support)
- For Linux: X11 or Wayland with Vulkan support

## Usage Example

```zig
const std = @import("std");
const rhi = @import("rhi/rhi.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    const allocator = gpa.allocator();

    // Initialize the renderer with Vulkan backend
    var renderer = try rhi.Renderer.init(allocator, .{
        .vk = .{
            .app_name = "MyApplication",
            .enable_validation_layer = true 
        },
    });
    defer renderer.deinit();

    // Enumerate available adapters (GPUs)
    var adapter = try rhi.PhysicalAdapter.enumerate_adapters(allocator, &renderer);
    defer adapter.deinit(allocator);

    // Create a device and start rendering...
}
```

## License

[Specify your license here]

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
