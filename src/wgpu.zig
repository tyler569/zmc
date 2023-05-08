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

    pub fn loadShaderModule(self: *Graphics) !c.WGPUShaderModule {
        const module_string = @embedFile("shader.wgsl");

        return c.wgpuDeviceCreateShaderModule(
            self.device,
            &zeroInit(c.WGPUShaderModuleDescriptor, .{
                .label = "shader_module",
                .nextInChain = @ptrCast(*const c.WGPUChainedStruct, &c.WGPUShaderModuleWGSLDescriptor{
                    .chain = c.WGPUChainedStruct{
                        .sType = c.WGPUSType_ShaderModuleWGSLDescriptor,
                        .next = null,
                    },
                    .code = module_string,
                }),
            }),
        ) orelse return error.CreateShaderModuleFailed;
    }

    pub fn createPipeline(self: *Graphics) !Pipeline {
        const shader_module = try self.loadShaderModule();

        const pipeline_layout = c.wgpuDeviceCreatePipelineLayout(
            self.device,
            &zeroInit(c.WGPUPipelineLayoutDescriptor, .{
                .label = "pipeline_layout",
            }),
        ) orelse return error.CreatePipelineLayoutFailed;

        const preferred_format = c.wgpuSurfaceGetPreferredFormat(
            self.surface,
            self.adapter,
        );
        if (preferred_format == c.WGPUTextureFormat_Undefined) {
            return error.GetPreferredFormatFailed;
        }

        const pipeline = c.wgpuDeviceCreateRenderPipeline(
            self.device,
            &c.WGPURenderPipelineDescriptor{
                .label = "render_pipeline",
                .layout = pipeline_layout,
                .vertex = c.WGPUVertexState{
                    .module = shader_module,
                    .entryPoint = "vs_main",
                    .nextInChain = null,
                    .constantCount = 0,
                    .constants = null,
                    .bufferCount = 0,
                    .buffers = null,
                },
                .fragment = &c.WGPUFragmentState{
                    .module = shader_module,
                    .entryPoint = "fs_main",
                    .nextInChain = null,
                    .constantCount = 0,
                    .constants = null,
                    .targetCount = 1,
                    .targets = &[1]c.WGPUColorTargetState{
                        zeroInit(c.WGPUColorTargetState, .{
                            .format = preferred_format,
                            .writeMask = c.WGPUColorWriteMask_All,
                        }),
                    },
                },
                .primitive = zeroInit(c.WGPUPrimitiveState, .{
                    .topology = c.WGPUPrimitiveTopology_TriangleList,
                }),
                .multisample = zeroInit(c.WGPUMultisampleState, .{
                    .count = 1,
                    .mask = 0xFFFF_FFFF,
                }),
                .depthStencil = null,
                .nextInChain = null,
            },
        ) orelse return error.CreateRenderPipelineFailed;

        return Pipeline{
            .pipeline = pipeline,
        };
    }
};

const Pipeline = struct {
    pipeline: c.WGPURenderPipeline,
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

fn handleUncapturedError(
    typ: c.WGPUErrorType,
    message: [*c]const u8,
    userdata: ?*anyopaque,
) callconv(.C) void {
    _ = userdata;
    print("uncapturedError type={} message=\"{s}\"\n", .{ typ, message });
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
    c.wgpuDeviceSetUncapturedErrorCallback(graphics.device, handleUncapturedError, null);
    return graphics;
}
