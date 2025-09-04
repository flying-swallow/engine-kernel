const rhi = @import("rhi.zig");
const volk = @import("volk");
const vma = @import("vma");
const std = @import("std");
const vulkan = @import("vulkan.zig");

//pub const ResourceLoader = @This();
pub const ResourceConfig = struct {
    max_sets: usize,
    buffer_size: usize,
};

pub const DefaultResourceConfig = ResourceConfig{
    .max_sets = 2,
    .buffer_size = 8 * (1024 * 1024), // 8 MB
};

pub const BufferTransaction = struct {
    target: rhi.Buffer,
    
    src_barrier: rhi.Buffer.Barrier,
    dst_barrier: rhi.Buffer.Barrier,

    region: []u8,
};

pub const TextureTransaction = struct {
    target: rhi.Image,

	// https://github.com/microsoft/DirectXTex/wiki/Image
	format: rhi.Format, // RI_Format_e 
	sliceNum: u32,
	rowPitch: u32,

	x: u16,
	y: u16,
	z: u16,
	width: u32,
	height: u32,
	depth: u32,

	array_offset: u32,
	mip_offset: u32,

    src_barrier: rhi.Image.Barrier,
    dst_barrier: rhi.Image.Barrier,

    // begin mapping
	align_row_pitch: u32,
	align_slice_pitch: u32,
    region: []u8,
};

const TransactionType = enum {

};

// ResourceLoader manages transfers of resources to the GPU
// Note: make sure buffers/images are associated with the currect device
pub fn ResourceLoader(comptime config: ResourceConfig) type {
    const CopyResourceSet = struct {
        pub const Self = @This();
        pool: rhi.Pool,
        cmd: rhi.Cmd,
        staging_buffer: rhi.Buffer,
        temporary_buffers: std.ArrayList(rhi.Buffer),
        backend: union {
            vk: rhi.wrapper_platform_type(.vk, struct {
                fence: volk.c.VkFence = null,
            }),
            dx12: rhi.wrapper_platform_type(.dx12, struct {}),
            mtl: rhi.wrapper_platform_type(.mtl, struct {}),
        },

        fn init(renderer: *rhi.Renderer, queue: *rhi.Queue, device: *rhi.Device) !Self {
            const staging_buffer: rhi.Buffer = if (rhi.is_target_selected(.vk, renderer)) result: {
                var res: rhi.Buffer = undefined;
                const allocation_info = vma.c.VmaAllocationCreateInfo{
                    .usage = vma.c.VMA_MEMORY_USAGE_AUTO,
                    .flags = vma.c.VMA_ALLOCATION_CREATE_MAPPED_BIT | vma.c.VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT,
                };
                const stage_buffer_create_info = volk.c.VkBufferCreateInfo{
                    .sType = volk.c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
                    .size = config.buffer_size,
                    .usage = volk.c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | volk.c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                };
                const vma_info = vma.c.VmaAllocationInfo{};
                try vulkan.wrap_err(vma.c.vmaCreateBuffer(device.backend.vk.vma_allocator, &stage_buffer_create_info, &allocation_info, &res.backend.vk.buffer, &res.backend.vk.allocation, &vma_info));
                res.mapped_region = @as([*c]u8, @ptrCast(vma_info.pMappedDatai))[0..config.buffer_size];
                break :result res;
            } else if (rhi.is_target_selected(.dx12, renderer)) {
                @compileError("Metal staging buffer not implemented");
            } else if (rhi.is_target_selected(.mtl, renderer)) {
                @compileError("Metal staging buffer not implemented");
            };

            const pool = rhi.Pool.init(renderer, device, queue);
            const cmd = rhi.Cmd.init(renderer, device, &pool);
            return .{
                .pool = pool,
                .cmd = cmd,
                .staging_buffer = staging_buffer,
            };
        }

    };

    return struct {
        pub const Self = @This();
        allocator: std.mem.Allocator,
        active_set: usize = 0,
        copy_resource: [config.max_sets]CopyResourceSet = undefined,
        upload_resource: [config.max_sets]CopyResourceSet = undefined,
        pub fn init(
            allocator: std.mem.Allocator,
            renderer: *rhi.Renderer,
            devices: *rhi.Device
        ) !ResourceLoader {
            var res = Self{
                .allocator = allocator,
            };
            for (config.max_sets) |i| {
                res.copy_resource[i] = CopyResourceSet.init(renderer, devices.renderer, &devices.graphics_queue);
                res.upload_resource[i] = CopyResourceSet.init(renderer, devices.renderer, if (devices.transfer_queue) |*t| t else &devices.graphics_queues);
            }
            return res;
        }

        pub fn begin_copy_buffer(renderer: *rhi.Renderer, cmd: *rhi.Cmd, device: *rhi.Device, transaction: BufferTransaction) !void {
            if (rhi.is_target_selected(.vk, renderer)) {
            
            } else if (rhi.is_target_selected(.dx12, renderer)) {

            } else if (rhi.is_target_selected(.mtl, renderer)) {
            
            }
        }

        pub fn end_copy_buffer(renderer: *rhi.Renderer, cmd: *rhi.Cmd, device: *rhi.Device, transaction: BufferTransaction) !void {
            if (rhi.is_target_selected(.vk, renderer)) {

            } else if (rhi.is_target_selected(.dx12, renderer)) {
                
            } else if (rhi.is_target_selected(.mtl, renderer)) {

            }
        }

        pub fn begin_copy_texture(renderer: *rhi.Renderer, cmd: *rhi.Cmd, device: *rhi.Device, transaction: TextureTransaction) !void {
            if (rhi.is_target_selected(.vk, renderer)) {
            
            } else if (rhi.is_target_selected(.dx12, renderer)) {

            } else if (rhi.is_target_selected(.mtl, renderer)) {
            
            }
        }

        pub fn end_copy_texture(renderer: *rhi.Renderer, cmd: *rhi.Cmd, device: *rhi.Device, transaction: TextureTransaction) !void {
            if (rhi.is_target_selected(.vk, renderer)) {

            } else if (rhi.is_target_selected(.dx12, renderer)) {
                
            } else if (rhi.is_target_selected(.mtl, renderer)) {

            }
        }
    };
}

// initialize a resource loader for a given device

//pub fn Texture(comptime config: rhi.BuildConfig) type {
//    return struct {
//        pub const Self = @This();
//        pub fn init() Self {
//            return Self{
//                .target = .{
//                    .vk = .{
//                        .image = undefined,
//                    },
//                }
//            };
//        }
//
//        target: union(rhi.Backend) {
//            vk: if (config.is_target_supported(.vk)) struct {
//                image: *volk.c.VkImage
//            } else void,
//            dx12: if (config.is_target_supported(.dx12)) struct {
//                // Vulkan-specific fields
//            } else void,
//            mtl: if (config.is_target_supported(.mtl)) struct {
//                // Vulkan-specific fields
//            } else void,
//        }
//    };
//}
