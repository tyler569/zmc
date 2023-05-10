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
    config: ?c.WGPUSwapChainDescriptor = null,
    swapchain: c.WGPUSwapChain = null,

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

    fn preferredFormat(self: *const Graphics) !c.WGPUTextureFormat {
        if (self.surface == null or self.adapter == null) {
            return error.GraphicsNotReady;
        }

        const preferred_format = c.wgpuSurfaceGetPreferredFormat(
            self.surface,
            self.adapter,
        );

        if (preferred_format == c.WGPUTextureFormat_Undefined) {
            return error.GetPreferredFormatFailed;
        }

        return preferred_format;
    }

    pub fn createPipeline(self: *Graphics) !Pipeline {
        const shader_module = try self.loadShaderModule();

        const pipeline_layout = c.wgpuDeviceCreatePipelineLayout(
            self.device,
            &zeroInit(c.WGPUPipelineLayoutDescriptor, .{
                .label = "pipeline_layout",
            }),
        ) orelse return error.CreatePipelineLayoutFailed;

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
                            .format = try self.preferredFormat(),
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

    pub fn renderPass(self: *Graphics, pipeline: Pipeline) !void {
        const next_texture = c.wgpuSwapChainGetCurrentTextureView(self.swapchain) orelse return error.GetCurrentTextureViewFailed;
        var command_encoder: c.WGPUCommandEncoder = c.wgpuDeviceCreateCommandEncoder(
            self.device,
            &zeroInit(c.WGPUCommandEncoderDescriptor, .{
                .label = "command_encoder",
            }),
        ) orelse return error.CreateCommandEncoderFailed;

        var render_pass_encoder: c.WGPURenderPassEncoder = c.wgpuCommandEncoderBeginRenderPass(
            command_encoder,
            &zeroInit(c.WGPURenderPassDescriptor, .{
                .label = "render_pass_encoder",
                .colorAttachmentCount = 1,
                .colorAttachments = &[1]c.WGPURenderPassColorAttachment{
                    zeroInit(c.WGPURenderPassColorAttachment, .{
                        .view = next_texture,
                        .loadOp = c.WGPULoadOp_Clear,
                        .storeOp = c.WGPUStoreOp_Store,
                        .clearValue = c.WGPUColor{
                            .r = 0.1,
                            .g = 0.2,
                            .b = 0.3,
                            .a = 1.0,
                        },
                    }),
                },
            }),
        );

        c.wgpuRenderPassEncoderSetPipeline(render_pass_encoder, pipeline.pipeline);
        c.wgpuRenderPassEncoderDraw(render_pass_encoder, 3, 1, 0, 0);
        c.wgpuRenderPassEncoderEnd(render_pass_encoder);

        c.wgpuTextureViewDrop(next_texture);

        const command_buffer = c.wgpuCommandEncoderFinish(
            command_encoder,
            &zeroInit(c.WGPUCommandBufferDescriptor, .{
                .label = "command_buffer",
            }),
        ) orelse return error.CommandEncoderFinishFailed;

        c.wgpuQueueSubmit(self.queue, 1, &command_buffer);

        c.wgpuSwapChainPresent(self.swapchain);
    }
};

pub const Pipeline = struct {
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

    const window_size = window.windowSize();
    graphics.config = c.WGPUSwapChainDescriptor{
        .usage = c.WGPUTextureUsage_RenderAttachment,
        .format = try graphics.preferredFormat(),
        .presentMode = c.WGPUPresentMode_Fifo,
        .width = @intCast(u32, window_size.width),
        .height = @intCast(u32, window_size.height),
        .nextInChain = null,
        .label = "swap_chain",
    };

    graphics.swapchain = c.wgpuDeviceCreateSwapChain(
        graphics.device,
        graphics.surface,
        &graphics.config.?,
    ) orelse return error.CreateSwapChainFailed;

    graphics.queue = c.wgpuDeviceGetQueue(graphics.device) orelse return error.GetQueueFailed;

    c.wgpuDeviceSetUncapturedErrorCallback(graphics.device, handleUncapturedError, null);
    return graphics;
}
