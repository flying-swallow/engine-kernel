const rhi = @import("rhi.zig");
const volk = @import("volk");
const vma = @import("vma");
const std = @import("std");
const vulkan = @import("vulkan.zig"); 

pub const PipelineLayout = @This();

pub const DescriptorType = enum(u8) {
    sampler,
    combined_image_sampler,
    sampled_image,
    storage_image,
    uniform_texel_buffer,
    storage_texel_buffer,
    uniform_buffer,
    storage_buffer,
    uniform_buffer_dynamic,
    storage_buffer_dynamic,
    input_attachment,
    inline_uniform_block,
    acceleration_structure, // VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR
};

pub const DescriptorRangeBits = enum(u8) { none = 0, paritially_bound = 1 << 0, array = 1 << 1, variable_sized_array = 1 << 2 };

backend: union {
    vk: rhi.wrapper_platform_type(.vk, struct { layout: volk.c.VkPipelineLayout }),
    dx12: rhi.wrapper_platform_type(.dx12, struct {}),
    mtl: rhi.wrapper_platform_type(.mtl, struct {}),
},

pub const DescriptorRangeDesc = struct {
    base_register_index: u32,
    descriptor_num: u32, // treated as max size if "VARIABLE_SIZED_ARRAY" flag is set
    descriptor_type: DescriptorType,
    shader_stages: rhi.StageBits,
    flags: DescriptorRangeBits,
};

pub const DynamicConstantBufferDesc = struct {
    register_index: u32,
    shader_stages: rhi.DescriptorStageBit,
};

pub const DescriptorSetDesc = struct {
    register_space: u32, // must be unique, avoid big gaps
    ranges: []DescriptorRangeDesc,
    dynamic_constant_buffers: []DynamicConstantBufferDesc,
};

pub fn init(allocator: std.mem.Allocator, renderer: *rhi.Renderer, device: *rhi.Device, desc: struct {
    descriptor_sets: []DescriptorSetDesc = &.{},
}) !PipelineLayout {
    if (rhi.is_target_selected(.vk, renderer)) {
        const BindingSet = struct {
            register_index: u32,
            descriptor_bindings: std.ArrayList(volk.c.VkDescriptorSetLayoutBinding),
            binding_flags: std.ArrayList(volk.c.VkDescriptorBindingFlags),
        };
		
		var register_count: u32 = 0;
		var pipeline_layout_create_info = volk.c.VkPipelineLayoutCreateInfo { .sType = volk.c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO };
        var bindings = std.ArrayList(BindingSet).empty;
        defer {
            for (bindings.items) |b| {
                b.descriptor_bindings.deinit(allocator);
                b.binding_flags.deinit(allocator);
            }
            bindings.deinit(allocator);
        }

        for (desc.descriptor_sets) |descriptor_set| {
            register_count = @max(descriptor_set.register_space + 1, register_count);
            for (descriptor_set.ranges) |descriptor_range| {
                const binding_set: *BindingSet = result: {
                    for (&bindings.items) |b| {
                        if (b.register_index == descriptor_set.register_space) {
                            break :result b;
                        }
                    }
                    try bindings.append(allocator, .{
                        .register_index = descriptor_set.register_space,
                        .descriptor_bindings = std.ArrayList(volk.c.VkDescriptorSetLayoutBinding).empty,
                        .binding_flags = std.ArrayList(volk.c.VkDescriptorBindingFlags).empty,
                    });
                    break :result &bindings.items[bindings.items.len - 1];
                };

                const layout_binding: volk.c.VkDescriptorSetLayoutBinding = .{
                    .binding = descriptor_range.base_register_index,
                    .descriptorType = switch (descriptor_range.descriptor_type) {
                        .sampler => volk.c.VK_DESCRIPTOR_TYPE_SAMPLER,
                        .combined_image_sampler => volk.c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                        .sampled_image => volk.c.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
                        .storage_image => volk.c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
                        .uniform_texel_buffer => volk.c.VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER,
                        .storage_texel_buffer => volk.c.VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER,
                        .uniform_buffer => volk.c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                        .storage_buffer => volk.c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                        .uniform_buffer_dynamic => volk.c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC,
                        .storage_buffer_dynamic => volk.c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC,
                        .input_attachment => volk.c.VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT,
                        .inline_uniform_block => volk.c.VK_DESCRIPTOR_TYPE_INLINE_UNIFORM_BLOCK_EXT,
                        .acceleration_structure => volk.c.VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR,
                    },
                    .descriptorCount = descriptor_range.descriptor_num,
                    .stageFlags = flags_res: {
                        var flags: u32 = 0;
                        if ((descriptor_range.shader_stages & .vertex_shader) != 0) {
                            flags |= volk.c.VK_SHADER_STAGE_VERTEX_BIT;
                        }
                        if ((descriptor_range.shader_stages & .fragment_shader) != 0) {
                            flags |= volk.c.VK_SHADER_STAGE_FRAGMENT_BIT;
                        }
                        if ((descriptor_range.shader_stages & .compute_shader) != 0) {
                            flags |= volk.c.VK_SHADER_STAGE_COMPUTE_BIT;
                        }
                        break :flags_res flags;
                    },
                };
                try binding_set.descriptor_bindings.append(allocator, layout_binding);
            }

        }

        const descriptor_set_layouts = try allocator.alloc(volk.c.VkDescriptorSetLayout, register_count);
        defer allocator.free(descriptor_set_layouts);

        const has_gaps = register_count > bindings.items.len;
        if(has_gaps) {
            var empty_layout: volk.c.VkDescriptorSetLayout = null;
            var create_layout = volk.c.VkDescriptorSetLayoutCreateInfo{
                .sType = volk.c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            };
            try vulkan.wrap_err(volk.c.vkCreateDescriptorSetLayout(device.backend.vk.device, &create_layout, null, &empty_layout));
            for(descriptor_set_layouts) |*dsl| dsl.* = empty_layout;
        }
        for(bindings.items) |b| {
			var binding_flag_info: volk.c.VkDescriptorSetLayoutBindingFlagsCreateInfo = .{ .sType = volk.c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO };
			binding_flag_info.bindingCount = b.binding_flags.items.len;
			binding_flag_info.pBindingFlags = b.binding_flags.items.ptr;

			var create_layout_info: volk.c.VkDescriptorSetLayoutCreateInfo  = .{ .sType = volk.c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO };
			create_layout_info.bindingCount = b.descriptor_bindings.items.len;
			create_layout_info.pBindings = b.descriptor_bindings.items.ptr;
			vulkan.add_next(&create_layout_info, &binding_flag_info);
            try vulkan.wrap_err(volk.c.vkCreateDescriptorSetLayout(device.backend.vk.device, &create_layout_info, null, &descriptor_set_layouts[b.register_index]));
        }
        pipeline_layout_create_info.pSetLayouts = descriptor_set_layouts;
        pipeline_layout_create_info.setLayoutCount = register_count;
        var pipeline_layout: volk.c.VkPipelineLayout = null;
        try vulkan.wrap_err(volk.c.vkCreatePipelineLayout(device.backend.vk.device, &pipeline_layout_create_info, null, &pipeline_layout));

        return .{ .backend = .{ .vk = .{
            .layout = pipeline_layout
        } } };
    } else if (rhi.is_target_selected(.dx12, renderer)) {} else if (rhi.is_target_selected(.mtl, renderer)) {}
}
