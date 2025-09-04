const rhi = @import("rhi.zig");
const volk = @import("volk");
const std = @import("std");
const vulkan = @import("vulkan.zig");

pub const FilterType = enum(u1) { 
    nearest = 0, 
    linear = 1 
};

pub const MipMapMode = enum(u1) { 
    nearest = 0, 
    linear = 1 
};

pub const CompareMode = enum(u3) { 
    never = 0, 
    less = 1, 
    equal = 2, 
    less_or_equal = 3, 
    greater = 4, 
    not_equal = 5, 
    greater_or_equal = 6, 
    always = 7 
};

pub const AddressMode = enum(u2) { 
    mirror = 0, 
    repeat = 1, 
    clamp_to_edge = 2, 
    clamp_to_border = 3 
};

pub const Sampler = @This();
backend: union(rhi.Backend) {
    vk: rhi.wrapper_platform_type(.vk, struct {
        sampler: volk.c.VkSampler = null,
    }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
},

pub fn descriptor(self: *Sampler) rhi.Descriptor {
    switch (self.backend) {
        .vk => |vk| {
            return .{
                .backend = .{
                    .vk = .{
                        .type = volk.c.VK_DESCRIPTOR_TYPE_SAMPLER,
                        .view = .{
                            .image = volk.c.VkDescriptorImageInfo{
                                .sampler = vk.sampler,
                                .imageView = null,
                                .imageLayout = volk.c.VK_IMAGE_LAYOUT_UNDEFINED,
                            }
                        }
                    }
                }
            };
        },
        .dx12 => {},
        .mtl => {},
    }
    return .{};
}

pub fn init(comptime selection: rhi.Selection, renderer: *rhi.Renderer, desc: switch(selection) {
    .default => struct {
        min_filter: FilterType,
        mag_filter: FilterType,
        mip_map_mode: MipMapMode,
        address_u: AddressMode,
        address_v: AddressMode,
        address_w: AddressMode,
        mip_lod_bias: f32,
        set_lod_range: bool,
        min_lod: f32,
        max_lod: f32,
        max_anisotropy: f32,
        compare_func: CompareMode,
    },
    .vk => struct {
    },
    .dx12 => struct {
    },
    .mtl => struct {
    }
}) Sampler {
    if (rhi.is_target_selected(.vk, renderer)) {
        std.debug.assert(selection == .default or selection == .vk); // ensure the selection matches the backend 
        var sampler_create_info = volk.c.VkSamplerCreateInfo{
            .sType = volk.c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .magFilter = switch(desc.mag_filter) {
                .nearest => volk.c.VK_FILTER_NEAREST,
                .linear => volk.c.VK_FILTER_LINEAR,
            },
            .minFilter = switch(desc.min_filter) {
                .nearest => volk.c.VK_FILTER_NEAREST,
                .linear => volk.c.VK_FILTER_LINEAR,
            },
            .mipmapMode = switch(desc.mip_map_mode) {
                .nearest => volk.c.VK_SAMPLER_MIPMAP_MODE_NEAREST,
                .linear => volk.c.VK_SAMPLER_MIPMAP_MODE_LINEAR,
            },
            .addressModeU = switch(desc.address_u) {
                .mirror => volk.c.VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT,
                .repeat => volk.c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
                .clamp_to_edge => volk.c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
                .clamp_to_border => volk.c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
            },
            .addressModeV = switch(desc.address_v) {
                .mirror => volk.c.VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT,
                .repeat => volk.c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
                .clamp_to_edge => volk.c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
                .clamp_to_border => volk.c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
            },
            .addressModeW = switch(desc.address_w) {
                .mirror => volk.c.VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT,
                .repeat => volk.c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
                .clamp_to_edge => volk.c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
                .clamp_to_border => volk.c.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
            },
            .mipLodBias = desc.mip_lod_bias,
            .anisotropyEnable = if (desc.max_anisotropy > 1.0) volk.c.VK_TRUE else volk.c.VK_FALSE,
            .maxAnisotropy = if (desc.max_anisotropy > 1.0) desc.max_anisotropy else 1.0
        };
        var sampler: volk.c.VkSampler = null;
        try vulkan.wrap_err(volk.c.vkCreateSampler.?(renderer.backend.vk.instance, &sampler_create_info, null, &sampler));
        return .{
            .backend = .{
                .vk = .{
                    .sampler = sampler  
                }
            }
        };
    } else if (rhi.is_target_selected(.dx12, renderer)) {
    } else if (rhi.is_target_selected(.mtl, renderer)) {
    }
    return error.UnsupportedBackend;
}

pub fn deinit(self: *Sampler) void {
    switch (self.backend) {
        .vk => |vk| {
            if (vk.sampler != null) {
                volk.c.vkDestroySampler.?(vk.sampler, null);
            }
        },
        .dx12 => {},
        .mtl => {},
    }
}
