const rhi = @import("rhi.zig");
const volk = @import("volk");

pub const Descriptor = @This();
backend: union(rhi.Backend) {
    vk: rhi.wrapper_platform_type(.vk, struct {
        type: volk.c.VkDescriptorType,
        view: union {
            image: volk.c.VkDescriptorImageInfo,
            buffer: volk.c.VkDescriptorBufferInfo,
        } 
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}), 
    mtl: rhi.wrapper_platform_type(.mtl, struct {}), 
},

pub const Ownership = enum(u8) {
    Owned,
    Borrowed
};

pub fn TextureDescriptor (texture: Ownership, sampler: Ownership) type {
    return struct {
        pub const Self = @This();

        pub fn descriptor(renderer: *rhi.Renderer) Descriptor {
            return .{
            };
        }

        pub fn init() Self {

        }

        pub fn deinit(self: *Self) void {

        }
    };
}


