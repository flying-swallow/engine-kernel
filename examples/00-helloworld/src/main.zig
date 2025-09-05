const std = @import("std");
const enginekit = @import("enginekit");
const rhi = enginekit.rhi;
const builtin = @import("builtin");

const sdl3 = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    @cInclude("SDL3/SDL_main.h");
});

var window: *sdl3.SDL_Window = undefined;
var allocator: std.mem.Allocator = undefined;
var renderer: rhi.Renderer = undefined;
var swapchain: rhi.Swapchain = undefined;
var device: rhi.Device = undefined;
var pool: rhi.Pool = undefined;
var resource_loader: rhi.ResourceLoader(rhi.resource_loader.DefaultResourceConfig) = undefined;
const FrameSet = struct {
    cmd: rhi.Cmd
};
var frames: [2]FrameSet = undefined;

/// Converts the return value of an SDL function to an error union.
inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}

const ErrorStore = struct {
    const status_not_stored = 0;
    const status_storing = 1;
    const status_stored = 2;

    status: sdl3.SDL_AtomicInt = .{},
    err: anyerror = undefined,
    trace_index: usize = undefined,
    trace_addrs: [32]usize = undefined,

    fn reset(es: *ErrorStore) void {
        _ = sdl3.SDL_SetAtomicInt(&es.status, status_not_stored);
    }

    fn store(es: *ErrorStore, err: anyerror) sdl3.SDL_AppResult {
        if (sdl3.SDL_CompareAndSwapAtomicInt(&es.status, status_not_stored, status_storing)) {
            es.err = err;
            if (@errorReturnTrace()) |src_trace| {
                es.trace_index = src_trace.index;
                const len = @min(es.trace_addrs.len, src_trace.instruction_addresses.len);
                @memcpy(es.trace_addrs[0..len], src_trace.instruction_addresses[0..len]);
            }
            _ = sdl3.SDL_SetAtomicInt(&es.status, status_stored);
        }
        return sdl3.SDL_APP_FAILURE;
    }

    fn load(es: *ErrorStore) ?anyerror {
        if (sdl3.SDL_GetAtomicInt(&es.status) != status_stored) return null;
        if (@errorReturnTrace()) |dst_trace| {
            dst_trace.index = es.trace_index;
            const len = @min(dst_trace.instruction_addresses.len, es.trace_addrs.len);
            @memcpy(dst_trace.instruction_addresses[0..len], es.trace_addrs[0..len]);
        }
        return es.err;
    }
};
var app_err: ErrorStore = .{};

fn sdlAppInit(appstate: ?*?*anyopaque, argv: [][*:0]u8) !sdl3.SDL_AppResult {
    _ = appstate;
    _ = argv;
    std.log.debug("SDL build time version: {d}.{d}.{d}", .{
        sdl3.SDL_MAJOR_VERSION,
        sdl3.SDL_MINOR_VERSION,
        sdl3.SDL_MICRO_VERSION,
    });
    std.log.debug("SDL build time revision: {s}", .{sdl3.SDL_REVISION});
    {
        const version = sdl3.SDL_GetVersion();
        std.log.debug("SDL runtime version: {d}.{d}.{d}", .{
            sdl3.SDL_VERSIONNUM_MAJOR(version),
            sdl3.SDL_VERSIONNUM_MINOR(version),
            sdl3.SDL_VERSIONNUM_MICRO(version),
        });
        const revision: [*:0]const u8 = sdl3.SDL_GetRevision();
        std.log.debug("SDL runtime revision: {s}", .{revision});
    }

    try errify(sdl3.SDL_SetAppMetadata("Speedbreaker", "0.0.0", "example.zig-examples.breakout"));

    try errify(sdl3.SDL_Init(sdl3.SDL_INIT_VIDEO));
    // We don't need to call 'SDL_Quit()' when using main callbacks.

    errify(sdl3.SDL_SetHint(sdl3.SDL_HINT_RENDER_VSYNC, "1")) catch {};

    window = try errify(sdl3.SDL_CreateWindow("00-helloworld", 640, 480, sdl3.SDL_WINDOW_RESIZABLE ));
    errdefer sdl3.SDL_DestroyWindow(window);
    renderer = try rhi.Renderer.init(allocator, .{
        .vk = .{ .app_name = "GraphicsKernel", .enable_validation_layer = true },
    });

    const window_handle: rhi.WindowHandle = p: {
        if(builtin.os.tag == .windows) {
        } else if(builtin.os.tag == .linux) {
            if(std.mem.eql(u8,std.mem.sliceTo(sdl3.SDL_GetCurrentVideoDriver(), 0), "x11")) {
                break :p rhi.WindowHandle{
                    .x11 = .{
                        .display = sdl3.SDL_GetPointerProperty(sdl3.SDL_GetWindowProperties(window), sdl3.SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null).?,
                        .window = @intFromPtr(sdl3.SDL_GetPointerProperty(sdl3.SDL_GetWindowProperties(window), sdl3.SDL_PROP_WINDOW_X11_WINDOW_NUMBER, null).?),
                    }
                };
            } else if(std.mem.eql(u8,std.mem.sliceTo(sdl3.SDL_GetCurrentVideoDriver(), 0), "wayland")) {
                break :p rhi.WindowHandle{
                    .wayland = .{
                        .display = sdl3.SDL_GetPointerProperty(sdl3.SDL_GetWindowProperties(window), sdl3.SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, null).?,
                        .surface = sdl3.SDL_GetPointerProperty(sdl3.SDL_GetWindowProperties(window), sdl3.SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, null).?,
                        .shell_surface = null
                    }
                };
            }
        } else if(builtin.os.tag == .macos or builtin.os.tag == .ios) {
        }
        return error.SdlError;
    };
    renderer = try rhi.Renderer.init(allocator, .{
        .vk = .{ .app_name = "GraphicsKernel", .enable_validation_layer = true },
    });
    var adapters = try rhi.PhysicalAdapter.enumerate_adapters(allocator, &renderer);
    errdefer adapters.deinit(allocator);

    var selected_adapter_index: usize = 0;
    for (adapters.items, 0..) |adp, idx| {
        if (@intFromEnum(adp.adapter_type) > @intFromEnum(adapters.items[selected_adapter_index].adapter_type))
            selected_adapter_index = idx;
        if (@intFromEnum(adp.adapter_type) < @intFromEnum(adapters.items[selected_adapter_index].adapter_type))
            continue;

        if (@intFromEnum(adp.preset_level) > @intFromEnum(adapters.items[selected_adapter_index].preset_level))
            selected_adapter_index = idx;
        if (@intFromEnum(adp.preset_level) < @intFromEnum(adapters.items[selected_adapter_index].preset_level))
            continue;

        if (adp.video_memory_size > adapters.items[selected_adapter_index].video_memory_size)
            selected_adapter_index = idx;
    }
    device = try rhi.Device.init(allocator, &renderer, &adapters.items[selected_adapter_index]);
    swapchain = try rhi.Swapchain.init(allocator, &renderer, &device, 640, 480, &device.graphics_queue, window_handle, .{});
    pool = try rhi.Pool.init(&renderer, &device, &device.graphics_queue);
    {
        var i: usize = 0;
        while (i < frames.len) : (i += 1) {
            frames[i].cmd = try rhi.Cmd.init(&renderer, &device, &pool);
        }
    }

    return sdl3.SDL_APP_CONTINUE;
}

fn sdlAppEvent(appstate: ?*anyopaque, event: *sdl3.SDL_Event) !sdl3.SDL_AppResult {
    _ = appstate;
    _ = event;
    return sdl3.SDL_APP_CONTINUE;
}

fn sdlAppIterate(appstate: ?*anyopaque) !sdl3.SDL_AppResult {
    _ = appstate;
    return sdl3.SDL_APP_CONTINUE;
}

fn sdlAppQuit(appstate: ?*anyopaque, result: anyerror!sdl3.SDL_AppResult) void {
    _ = appstate;
    _ = result catch |err| if (err == error.SdlError) {
        std.log.err("{s}", .{sdl3.SDL_GetError()});
    };
    renderer.deinit();
}

fn sdlAppInitC(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) sdl3.SDL_AppResult {
    return sdlAppInit(appstate.?, @ptrCast(argv.?[0..@intCast(argc)])) catch |err| app_err.store(err);
}

fn sdlAppIterateC(appstate: ?*anyopaque) callconv(.c) sdl3.SDL_AppResult {
    return sdlAppIterate(appstate) catch |err| app_err.store(err);
}

fn sdlAppEventC(appstate: ?*anyopaque, event: ?*sdl3.SDL_Event) callconv(.c) sdl3.SDL_AppResult {
    return sdlAppEvent(appstate, event.?) catch |err| app_err.store(err);
}

fn sdlAppQuitC(appstate: ?*anyopaque, result: sdl3.SDL_AppResult) callconv(.c) void {
    sdlAppQuit(appstate, app_err.load() orelse result);
}

fn sdlMainC(argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return sdl3.SDL_EnterAppMainCallbacks(argc, @ptrCast(argv), sdlAppInitC, sdlAppIterateC, sdlAppEventC, sdlAppQuitC);
}

pub fn main() !u8{ 
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    allocator = gpa.allocator();
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(sdl3.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), sdlMainC, null))));
    return app_err.load() orelse status;

}

