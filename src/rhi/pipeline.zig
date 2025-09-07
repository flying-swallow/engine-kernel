const rhi = @import("rhi.zig");
const volk = @import("volk");
const std = @import("std");
const vulkan = @import("vulkan.zig");
pub const DescriptorSetBinding = struct {};

pub const FillMode = enum(u8) { solid, wireframe };

pub const ColorWriteBits = enum(u8) {
    none = 0,
    r = 1 << 0,
    g = 1 << 1,
    b = 1 << 2,
    a = 1 << 3,
    rgb = .r | .g | .b,
    rgba = .r | .g | .b | .a,
};

fn color_write_bits_to_vk(bits: ColorWriteBits) volk.c.VkColorComponentFlags {
    var flags: volk.c.VkColorComponentFlags = 0;
    if ((bits & .r) != 0) {
        flags |= volk.c.VK_COLOR_COMPONENT_R_BIT;
    }
    if ((bits & .g) != 0) {
        flags |= volk.c.VK_COLOR_COMPONENT_G_BIT;
    }
    if ((bits & .b) != 0) {
        flags |= volk.c.VK_COLOR_COMPONENT_B_BIT;
    }
    if ((bits & .a) != 0) {
        flags |= volk.c.VK_COLOR_COMPONENT_A_BIT;
    }
    return flags;
}

pub const LogicFunc = enum(u8) {
    _none,
    _clear, // 0
    _and, // s & d
    _and_reverse, // s & ~d
    _copy, // s
    _and_inverted, // ~s & d
    _xor, // s ^ d
    _or, // s | d
    _nor, // ~(s | d)
    _equivalent, // ~(s ^ d)
    _invert, // ~d
    _or_reverse, // s | ~d
    _copy_inverted, // ~s
    _or_inverted, // ~s | d
    _nand, // ~(s & d)
    _set, // 1
};

pub const StencilFunc = enum(u8) { keep, zero, replace, increment_and_clamp, decrement_and_clamp, invert, increment_and_wrap, decrement_and_wrap };

pub const CullMode = enum(u8) {
    none,
    front,
    back,
};

pub const BlendFunc = enum(u8) { add, subtract, reverse_subtract, min, max };
pub fn blend_func_to_vk(func: BlendFunc) volk.c.VkBlendOp {
    return switch (func) {
        .add => volk.c.VK_BLEND_OP_ADD,
        .subtract => volk.c.VK_BLEND_OP_SUBTRACT,
        .reverse_subtract => volk.c.VK_BLEND_OP_REVERSE_SUBTRACT,
        .min => volk.c.VK_BLEND_OP_MIN,
        .max => volk.c.VK_BLEND_OP_MAX,
    };
}

pub const BlendFactor = enum(u8) {
    zero,
    one,
    src_color,
    one_minus_src_color,
    dst_color,
    one_minus_dst_color,
    src_alpha,
    one_minus_src_alpha,
    dst_alpha,
    one_minus_dst_alpha,
    constant_color,
    one_minus_constant_color,
    constant_alpha,
    one_minus_constant_alpha,
    src_alpha_saturate,
};

pub fn blend_factor_to_vk(factor: BlendFactor) volk.c.VkBlendFactor {
    return switch (factor) {
        .zero => volk.c.VK_BLEND_FACTOR_ZERO,
        .one => volk.c.VK_BLEND_FACTOR_ONE,
        .src_color => volk.c.VK_BLEND_FACTOR_SRC_COLOR,
        .one_minus_src_color => volk.c.VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR,
        .dst_color => volk.c.VK_BLEND_FACTOR_DST_COLOR,
        .one_minus_dst_color => volk.c.VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR,
        .src_alpha => volk.c.VK_BLEND_FACTOR_SRC_ALPHA,
        .one_minus_src_alpha => volk.c.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .dst_alpha => volk.c.VK_BLEND_FACTOR_DST_ALPHA,
        .one_minus_dst_alpha => volk.c.VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA,
        .constant_color => volk.c.VK_BLEND_FACTOR_CONSTANT_COLOR,
        .one_minus_constant_color => volk.c.VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR,
        .constant_alpha => volk.c.VK_BLEND_FACTOR_CONSTANT_ALPHA,
        .one_minus_constant_alpha => volk.c.VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA,
        .src_alpha_saturate => volk.c.VK_BLEND_FACTOR_SRC_ALPHA_SATURATE,
    };
}

pub const Toplogy = enum(u8) { point_list, line_list, line_strip, triangle_list, triangle_strip, line_list_with_adjacency, line_strip_with_adjacency, triangle_list_with_adjacency, triangle_strip_with_adjacency, patch_list };

pub const CompareFunc = enum(u8) { never, less, equal, less_equal, greater, not_equal, greater_equal, always };

pub const GraphicsPipeline = struct {
    backend: union {
        vk: rhi.wrapper_platform_type(.vk, struct {
            pipeline: volk.c.VkPipeline = null,
        }),
        dx12: rhi.wrapper_platform_type(.dx12, struct {}),
        mtl: rhi.wrapper_platform_type(.mtl, struct {}),

        pub fn init_graphics_pipeline(renderer: *rhi.Renderer, device: *rhi.Device, desc: GraphicsPipelineDesc) !GraphicsPipeline {
            if (rhi.is_target_selected(.vk, renderer)) {
                var vertex_binding_desc: [32]volk.c.VkVertexInputAttributeDescription = undefined;
                var vertex_input_streams_desc: [8]volk.c.VkVertexInputBindingDescription = undefined;
                var vertex_input_state = volk.c.VkPipelineVertexInputStateCreateInfo{ .sType = volk.c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO };
                var color_blend_attachment_desc: [8]volk.c.VkPipelineColorBlendAttachmentState = undefined;
                var pipeline_create_info = volk.c.VkGraphicsPipelineCreateInfo{ .sType = volk.c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO };
                var color_blend_state = volk.c.VkPipelineColorBlendStateCreateInfo{ .sType = volk.c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO };

                var shader_modules: [8]volk.c.VkShaderModule = undefined;
                defer {
                    for (desc.shaders.len) |i| {
                        volk.c.vkDestroyShaderModule.?(device.backend.vk.device, shader_modules[i], null);
                    }
                }
                var stage_create_infos: [8]volk.c.VkPipelineShaderStageCreateInfo = undefined;
                std.debug.assert(desc.shaders.len <= shader_modules.len);
                for (desc.shaders, 0..) |shader, i| {
                    var shader_module_create_info = volk.c.VkShaderModuleCreateInfo{ .sType = volk.c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO };
                    shader_module_create_info.codeSize = @as(usize, @intCast(shader.code.len)) / @sizeOf(u32);
                    shader_module_create_info.pCode = @ptrCast(shader.code.ptr);
                    try vulkan.wrap_err(volk.c.vkCreateShaderModule.?(device.backend.vk.device, &shader_module_create_info, null, &shader_modules[i]));
                    stage_create_infos[i] = volk.c.VkPipelineShaderStageCreateInfo{
                        .sType = volk.c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                        .stage = res_stage: {
                            if (shader.stage == .all)
                                return volk.c.VK_SHADER_STAGE_ALL;

                            // Gather bits
                            var stage_flags: volk.c.VkShaderStageFlags = 0;

                            if ((shader.stage & .vertex_shader) > 0)
                                stage_flags |= volk.c.VK_SHADER_STAGE_VERTEX_BIT;

                            if ((shader.stage & .tess_control_shader) > 0)
                                stage_flags |= volk.c.VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT;

                            if ((shader.stage & .tess_evaluation_shader) > 0)
                                stage_flags |= volk.c.VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT;

                            if ((shader.stage & .geometry_shader) > 0)
                                stage_flags |= volk.c.VK_SHADER_STAGE_GEOMETRY_BIT;

                            if ((shader.stage & .fragment_shader) > 0)
                                stage_flags |= volk.c.VK_SHADER_STAGE_FRAGMENT_BIT;

                            if (shader.stage & .compute_shader)
                                stage_flags |= volk.c.VK_SHADER_STAGE_COMPUTE_BIT;

                            if (shader.stage & .raygen_shader)
                                stage_flags |= volk.c.VK_SHADER_STAGE_RAYGEN_BIT_KHR;

                            if (shader.stage & .miss_shader)
                                stage_flags |= volk.c.VK_SHADER_STAGE_MISS_BIT_KHR;

                            if (shader.stage & .intersection_shader)
                                stage_flags |= volk.c.VK_SHADER_STAGE_INTERSECTION_BIT_KHR;

                            if (shader.stage & .closest_hit_shader)
                                stage_flags |= volk.c.VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR;

                            if (shader.stage & .any_hit_shader)
                                stage_flags |= volk.c.VK_SHADER_STAGE_ANY_HIT_BIT_KHR;

                            if (shader.stage & .callable_shader)
                                stage_flags |= volk.c.VK_SHADER_STAGE_CALLABLE_BIT_KHR;

                            if (shader.stage & .mesh_control_shader)
                                stage_flags |= volk.c.VK_SHADER_STAGE_TASK_BIT_EXT;

                            if (shader.stage & .mesh_evaluation_shader)
                                stage_flags |= volk.c.VK_SHADER_STAGE_MESH_BIT_EXT;
                            break :res_stage stage_flags;
                        },
                        .module = shader_modules[i],
                        .pName = shader.entry_point.ptr,
                    };
                }

                if (desc.vertex_input) |vi| {
                    std.debug.assert(vi.vertex_attributes.len <= vertex_binding_desc.len);
                    std.debug.assert(vi.vertex_stream.len <= vertex_input_streams_desc.len);
                    for (vi.vertex_attributes, 0..) |attr, i| {
                        vertex_binding_desc[i] = volk.c.VkVertexInputAttributeDescription{
                            .location = if (attr.vk) |vk_attr| vk_attr.location else 0,
                            .binding = attr.stream_index,
                            .format = rhi.format.to_vk_format(attr.format),
                            .offset = @intCast(attr.offset),
                        };
                    }
                    for (vi.vertex_stream, 0..) |stream, i| {
                        vertex_input_streams_desc[i] = volk.c.VkVertexInputBindingDescription{
                            .binding = stream.bindingSlot,
                            .stride = stream.stride,
                            .inputRate = volk.c.VK_VERTEX_INPUT_RATE_VERTEX,
                        };
                    }
                    vertex_input_state.vertexAttributeDescriptionCount = vi.vertex_attributes.len;
                    vertex_input_state.pVertexAttributeDescriptions = &vertex_binding_desc[0];
                    vertex_input_state.vertexBindingDescriptionCount = vi.vertex_stream.len;
                    vertex_input_state.pVertexBindingDescriptions = &vertex_input_streams_desc[0];
                }
                for (desc.output_merger.colors, 0..) |attachment, i| {
                    color_blend_attachment_desc[i] = .{
                        .blendEnable = if (attachment.enabled) volk.c.VK_TRUE else volk.c.VK_FALSE,
                        .srcColorBlendFactor = blend_factor_to_vk(attachment.color_blend.src_factor),
                        .dstColorBlendFactor = blend_factor_to_vk(attachment.color_blend.dst_factor),
                        .colorBlendOp = blend_func_to_vk(attachment.color_blend.func),
                        .srcAlphaBlendFactor = blend_factor_to_vk(attachment.alpha_blend.src_factor),
                        .dstAlphaBlendFactor = blend_factor_to_vk(attachment.alpha_blend.dst_factor),
                        .alphaBlendOp = blend_func_to_vk(attachment.alpha_blend.func),
                        .colorWriteMask = color_write_bits_to_vk(attachment.write_mask),
                    };
                }
                color_blend_state.attachmentCount = desc.output_merger.colors.len;
                color_blend_state.pAttachments = color_blend_attachment_desc.ptr;

                pipeline_create_info.pStages = stage_create_infos.len;
                pipeline_create_info.stageCount = @intCast(desc.shaders.len);
                pipeline_create_info.pVertexInputState = &vertex_input_state;
                pipeline_create_info.layout = desc.pipeline_layout.backend.vk.layout;
                pipeline_create_info.basePipelineIndex = -1;

                var graphics_pipeline: volk.c.VkPipeline = null;
                try vulkan.wrap_err(volk.c.vkCreateGraphicsPipelines.?(device.backend.vk.device, null, 1, &pipeline_create_info, null, &graphics_pipeline));
                return .{ .backend = .{ .vk = .{ .pipeline = graphics_pipeline } } };
            } else if (rhi.is_target_selected(.dx12, renderer)) {} else if (rhi.is_target_selected(.mtl, renderer)) {}
            return error.UnsupportedBackend;
        }
    },
};

pub const ShaderDesc = struct {
    pub const Self = @This();
    stage: rhi.PipelineLayout.StageBits,
    code: []const u8,
    entry_point: []const u8 = "main",
};

pub const GraphicsPipelineDesc = struct {
    pub const VertexAttribute = struct { d3d: ?struct { semantic_name: []const u8, semantic_index: u32 }, vk: ?struct { location: u32 }, offset: usize, format: rhi.Format, stream_index: u16 };

    pub const VertexStream = struct { stride: u16, bindingSlot: u16 };

    pub const BlendDesc = struct {
        src_factor: BlendFactor,
        dst_factor: BlendFactor,
        func: BlendFunc,
    };

    pub const StencilDesc = struct {
        compare_func: CompareFunc = .never,
        fail: StencilFunc = .keep,
        pass: StencilFunc = .keep,
        depth_fail: StencilFunc = .keep,
        write_mask: u8 = 0,
        read_mask: u8 = 0,
    };

    pub const StencilAttachmentDesc = struct {
        front: StencilDesc = .{},
        back: StencilDesc = .{},
    };

    pub const DepthAttachmentDesc = struct {
        compareFunc: CompareFunc = .never,
        write: bool = false,
        bound_test: bool = false, // requires "isDepthBoundsTestSupported", expects "CmdSetDepthBounds"
    };

    pub const ColorAttachmentDesc = struct {
        format: rhi.Format,
        color_blend: BlendDesc,
        alpha_blend: BlendDesc,
        write_mask: ColorWriteBits,
        enabled: bool = false,
    };

    pub const Self = @This();
    pipeline_layout: *rhi.PipelineLayout = undefined,
    vertex_input: ?struct {
        vertex_attributes: []VertexAttribute = &.{},
        vertex_stream: []VertexStream = &.{},
    } = null,
    input_assembly: struct {
        topology: Toplogy = .triangle_list,
    },
    rasterization: struct {
        viewport_num: u32,
        //R - minimum resolvable difference
        //S - maximum slope
        //
        //bias = constant * R + slopeFactor * S
        //if (clamp > 0)
        //    bias = min(bias, clamp)
        //else if (clamp < 0)
        //    bias = max(bias, clamp)
        //
        //enabled if constant != 0 or slope != 0
        depth_bias: struct {
            constant: f32 = 0,
            clamp: f32 = 0,
            slope: f32 = 0,
        },
        fill_mode: FillMode = .solid,
        cull_mode: CullMode = .none,
        front_counter_clockwise: bool = false,
        //depthClamp: bool = false,
        //lineSmoothing: bool = false,         // requires "isLineSmoothingSupported"
        //conservativeRaster: bool = false,    // requires "conservativeRasterTier != 0"
        //shadingRate: bool = false           // requires "shadingRateTier != 0", expects "CmdSetShadingRate" and optionally "AttachmentsDesc::shadingRate"
    },
    multisample: ?struct {
        sample_mask: u32 = 0,
        sample_num: u8 = 0,
        alpha_to_coverage: bool = false,
        //sample_locations: bool = false,
    },
    output_merger: struct {
        colors: []ColorAttachmentDesc = &.{},
        depth: DepthAttachmentDesc = .{},
        stencil: StencilAttachmentDesc = .{},
        depthStencilFormat: rhi.Format = .unknown,
        logicFunc: LogicFunc = ._none, // requires "isLogicFuncSupported"
    },
    shaders: []ShaderDesc,
};
