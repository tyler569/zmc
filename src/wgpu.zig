const std = @import("std");
const print = std.debug.print;
const zeroInit = std.mem.zeroInit;

const sdl = @import("sdl.zig");
const mesh = @import("mesh.zig");
const buffer = @import("buffer.zig");

const c = @cImport({
    @cInclude("wgpu.h");
});

pub const Graphics = struct {
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

    pub fn createPipeline(self: *Graphics, vertex_buffers: anytype, uniform_buffers: anytype) !Pipeline {
        const shader_module = try self.loadShaderModule();

        const VertexType = @TypeOf(vertex_buffers);
        const vertex_info = @typeInfo(VertexType);
        const UniformType = @TypeOf(uniform_buffers);
        const uniform_info = @typeInfo(UniformType);

        if (vertex_info != .Struct) {
            @compileError("expected tuple or struct argument, found " ++ @typeName(VertexType));
        }
        if (uniform_info != .Struct) {
            @compileError("expected tuple or struct argument, found " ++ @typeName(UniformType));
        }

        const vertex_fields = vertex_info.Struct.fields;
        const uniform_fields = uniform_info.Struct.fields;

        const bind_group_count = uniform_fields.len;
        var bind_group_layouts: [bind_group_count]c.WGPUBindGroupLayout = undefined;
        inline for (uniform_fields, 0..) |field, i| {
            bind_group_layouts[i] = @field(uniform_buffers, field.name).bind_group_layout;
        }

        const vertex_buffer_count = vertex_fields.len;
        var vertex_buffer_layouts: [vertex_buffer_count]c.WGPUVertexBufferLayout = undefined;
        inline for (vertex_fields, 0..) |field, i| {
            // vertex_buffer_layouts[i] = @field(vertex_buffers, field.name).layout();
            vertex_buffer_layouts[i] = field.type.layout();
        }

        const pipeline_layout = c.wgpuDeviceCreatePipelineLayout(
            self.device,
            &zeroInit(c.WGPUPipelineLayoutDescriptor, .{
                .label = "pipeline_layout",
                .bindGroupLayoutCount = bind_group_count,
                .bindGroupLayouts = &bind_group_layouts,
            }),
        ) orelse return error.CreatePipelineLayoutFailed;

        // Want to take a tuple of types in the future
        //
        // const info = @typeInfo(@TypeOf(Ts));
        // if (info != .Struct or !info.Struct.is_tuple) {
        //     @compileError("createPipeline expects a tuple of types, found: " ++ @typeName(Ts));
        // }

        // const buffer_count = info.Struct.fields.len;
        // comptime var buffer_descs: [buffer_count]c.WGPUVertexBufferLayout = undefined;
        // inline for (info.Struct.fields, 0..) |field, i| {
        //     @compileLog("type is " ++ @typeName(field.type));
        //     buffer_descs[i] = try buffer.vertexBufferLayout(field.type);
        // }

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
                    .bufferCount = vertex_buffer_count,
                    .buffers = &vertex_buffer_layouts,
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

    pub fn render(self: *Graphics) !RenderFrame {
        return RenderFrame.init(self);
    }

    pub fn createVertexBufferInit(
        self: *Graphics,
        comptime T: type,
        contents: []const T,
    ) !buffer.VertexBuffer(T) {
        return buffer.VertexBuffer(T).init(self, contents);
    }

    pub fn createUniformBufferInit(
        self: *Graphics,
        comptime T: type,
        contents: T,
    ) !buffer.UniformBuffer(T) {
        return buffer.UniformBuffer(T).init(self, contents);
    }
};

pub const RenderFrame = struct {
    graphics: *Graphics,
    command_encoder: c.WGPUCommandEncoder,
    texture: c.WGPUTextureView,

    pub fn init(graphics: *Graphics) !RenderFrame {
        const next_texture = c.wgpuSwapChainGetCurrentTextureView(graphics.swapchain) orelse
            return error.GetCurrentTextureViewFailed;
        const command_encoder: c.WGPUCommandEncoder = c.wgpuDeviceCreateCommandEncoder(
            graphics.device,
            &zeroInit(c.WGPUCommandEncoderDescriptor, .{
                .label = "command_encoder",
            }),
        ) orelse return error.CreateCommandEncoderFailed;

        return RenderFrame{
            .graphics = graphics,
            .command_encoder = command_encoder,
            .texture = next_texture,
        };
    }

    pub fn renderPass(
        self: *RenderFrame,
        pipeline: *Pipeline,
        op: RenderOp,
    ) !RenderPass {
        return RenderPass.init(self, pipeline, op);
    }

    pub fn finish(self: *RenderFrame) !void {
        c.wgpuTextureViewDrop(self.texture);

        const command_buffer = c.wgpuCommandEncoderFinish(
            self.command_encoder,
            &zeroInit(c.WGPUCommandBufferDescriptor, .{
                .label = "command_buffer",
            }),
        ) orelse return error.CommandEncoderFinishFailed;

        c.wgpuQueueSubmit(self.graphics.queue, 1, &command_buffer);

        c.wgpuSwapChainPresent(self.graphics.swapchain);
    }
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn wgpuColor(self: *const Color) c.WGPUColor {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = self.a };
    }
};

pub const RenderOp = union(enum) {
    clear: Color,
    store: void,
};

pub const RenderPass = struct {
    frame: *RenderFrame,
    pipeline: *Pipeline,
    encoder: c.WGPURenderPassEncoder,

    vertices: ?usize = null,
    next_bind_group: u32 = 0,

    fn init(frame: *RenderFrame, pipeline: *Pipeline, op: RenderOp) !RenderPass {
        const color_attachment = switch (op) {
            .clear => |color| zeroInit(c.WGPURenderPassColorAttachment, .{
                .view = frame.texture,
                .loadOp = c.WGPULoadOp_Clear,
                .storeOp = c.WGPUStoreOp_Store,
                .clearValue = color.wgpuColor(),
            }),
            .store => zeroInit(c.WGPURenderPassColorAttachment, .{
                .view = frame.texture,
                .loadOp = c.WGPULoadOp_Load,
                .storeOp = c.WGPUStoreOp_Store,
            }),
        };

        const render_pass_encoder: c.WGPURenderPassEncoder = c.wgpuCommandEncoderBeginRenderPass(
            frame.command_encoder,
            &zeroInit(c.WGPURenderPassDescriptor, .{
                .label = "render_pass_encoder",
                .colorAttachmentCount = 1,
                .colorAttachments = &[1]c.WGPURenderPassColorAttachment{
                    color_attachment,
                },
            }),
        );

        c.wgpuRenderPassEncoderSetPipeline(render_pass_encoder, pipeline.pipeline);

        return RenderPass{
            .frame = frame,
            .pipeline = pipeline,
            .encoder = render_pass_encoder,
        };
    }

    pub fn attachBuffer(self: *RenderPass, buf: anytype) !void {
        self.vertices = buf.vertex_count;
        c.wgpuRenderPassEncoderSetVertexBuffer(self.encoder, 0, buf.buffer, 0, buf.size);
    }

    pub fn attachUniform(self: *RenderPass, buf: anytype) !void {
        c.wgpuRenderPassEncoderSetBindGroup(self.encoder, self.next_bind_group, buf.bind_group, 0, null);
    }

    pub fn draw(self: *RenderPass) !void {
        c.wgpuRenderPassEncoderDraw(self.encoder, @intCast(u32, self.vertices orelse 0), 1, 0, 0);
        c.wgpuRenderPassEncoderEnd(self.encoder);
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
        .nextInChain = @ptrCast(*const c.WGPUChainedStruct, &c.WGPUSurfaceDescriptorFromMetalLayer{
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
