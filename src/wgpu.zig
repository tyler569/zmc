const std = @import("std");
const print = std.debug.print;
const zeroInit = std.mem.zeroInit;

const sdl = @import("sdl.zig");

const c = @cImport({
    @cInclude("wgpu.h");
});

const Graphics = struct {
    instance: c.WGPUInstance = null,
    surface: c.WGPUSurface = null,
    adapter: c.WGPUAdapter = null,
    device: c.WGPUDevice = null,
    queue: c.WGPUQueue = null,
};

const GraphicsPtr = opaque {};

fn handleRequestAdapter(
    status: c.WGPURequestAdapterStatus,
    adapter: c.WGPUAdapter,
    message: [*c]const u8,
    userdata: ?*anyopaque,
) callconv(.C) void {
    switch (status) {
        c.WGPURequestAdapterStatus_Success => {
            const graphics = @ptrCast(*Graphics, @alignCast(8, userdata));
            graphics.adapter = adapter;
        },
        else => {
            print("requestAdapter status={} message=\"{s}\"\n", .{ status, message });
        },
    }
}

fn handleRequestDevice(
    status: c.WGPURequestDeviceStatus,
    device: c.WGPUDevice,
    message: [*c]const u8,
    userdata: ?*anyopaque,
) callconv(.C) void {
    switch (status) {
        c.WGPURequestDeviceStatus_Success => {
            const graphics = @ptrCast(*Graphics, @alignCast(8, userdata));
            graphics.device = device;
        },
        else => {
            print("requestDevice status={} message=\"{s}\"\n", .{ status, message });
        },
    }
}

pub fn init(window: *const sdl.Window) !Graphics {
    var graphics = Graphics{};
    graphics.instance = c.wgpuCreateInstance(&zeroInit(c.WGPUInstanceDescriptor, .{})) orelse return error.CreateInstanceFailed;

    graphics.surface = c.wgpuInstanceCreateSurface(graphics.instance, &c.WGPUSurfaceDescriptor{
        .label = "Screen surface",
        .nextInChain = @ptrCast(*c.WGPUChainedStruct, &c.WGPUSurfaceDescriptorFromMetalLayer{
            .chain = c.WGPUChainedStruct{
                .sType = c.WGPUSType_SurfaceDescriptorFromMetalLayer,
                .next = null,
            },
            .layer = window.nativeLayer(),
        }),
    });

    c.wgpuInstanceRequestAdapter(
        graphics.instance,
        &zeroInit(c.WGPURequestAdapterOptions, .{
            .compatibleSurface = graphics.surface,
        }),
        handleRequestAdapter,
        @ptrCast(?*GraphicsPtr, &graphics),
    );

    c.wgpuAdapterRequestDevice(
        graphics.adapter,
        null,
        handleRequestDevice,
        @ptrCast(?*GraphicsPtr, &graphics),
    );

    graphics.queue = c.wgpuDeviceGetQueue(graphics.device) orelse return error.GetQueueFailed;
    return graphics;
}
