const std = @import("std");
const print = std.debug.print;
const expectEqual = std.testing.expectEqual;
const zeroInit = std.mem.zeroInit;

const wgpu = @import("wgpu.zig");
const c = @cImport({
    @cInclude("wgpu.h");
});

fn vertexFormat(comptime T: type) c.WGPUVertexFormat {
    return switch (T) {
        [2]f32 => c.WGPUVertexFormat_Float32x2,
        [3]f32 => c.WGPUVertexFormat_Float32x3,
        [4]f32 => c.WGPUVertexFormat_Float32x4,
        else => {
            @compileError("Error: No definition for value of type " ++ @typeName(T) ++ " in buffer.zig");
        },
    };
}

// TODO: I'd like to transition users of this to VertexBuffer.layout()
// and make this private in the future.
pub fn vertexBufferLayout(comptime T: type) c.WGPUVertexBufferLayout {
    const info = @typeInfo(T);
    if (info != .Struct) {
        @compileError("Error: Vertex buffers must consist of extern structs, found " ++ @typeName(T) ++ "\n");
    }

    const struct_info = info.Struct;

    if (struct_info.layout != .Extern) {
        @compileError("Error: Vertex buffers must consist of extern structs, found " ++ @typeName(T) ++ "\n");
    }

    const attribute_count = struct_info.fields.len;

    // This creates a unique struct for each T, creating a persistent static
    // array unique to every Vertex type input.
    const attributes = struct {
        var a: [attribute_count]c.WGPUVertexAttribute = undefined;
    };

    inline for (struct_info.fields, 0..) |*field, ix| {
        attributes.a[ix] = c.WGPUVertexAttribute{
            .offset = @offsetOf(T, field.name),
            .shaderLocation = ix,
            .format = vertexFormat(field.type),
        };
    }

    return c.WGPUVertexBufferLayout{
        .arrayStride = @sizeOf(T),
        .stepMode = c.WGPUVertexStepMode_Vertex,
        .attributeCount = attribute_count,
        .attributes = &attributes.a,
    };
}

test "buffer layout" {
    const Vertex = extern struct {
        position: [3]f32,
        color: [4]f32,
    };

    const buffer_layout = try vertexBufferLayout(Vertex);

    try expectEqual(buffer_layout.attributes[0].offset, 0);
    try expectEqual(buffer_layout.attributes[1].offset, 12);
}

const BufferUsage = enum {
    vertex,
    uniform,

    fn wgpuValue(usage: BufferUsage) u32 {
        return switch (usage) {
            .vertex => c.WGPUBufferUsage_Vertex,
            .uniform => c.WGPUBufferUsage_Uniform | c.WGPUBufferUsage_CopyDst,
        };
    }
};

fn createBuffer(
    graphics: *const wgpu.Graphics,
    contents: []const u8,
    label: ?[]const u8,
    usage: BufferUsage,
) c.WGPUBuffer {
    const size = contents.len;

    const wgpu_buffer = c.wgpuDeviceCreateBuffer(
        graphics.device,
        &c.WGPUBufferDescriptor{
            .size = size,
            .label = if (label) |l| l.ptr else null,
            .usage = usage.wgpuValue(),
            .mappedAtCreation = true,
            .nextInChain = null,
        },
    );
    const data_opaque = c.wgpuBufferGetMappedRange(wgpu_buffer, 0, size);
    const data = @ptrCast([*]u8, data_opaque);

    @memcpy(data, contents);

    c.wgpuBufferUnmap(wgpu_buffer);

    return wgpu_buffer;
}

// Needed because @ptrCast to a different size is TODO in the compiler
// would prefer @ptrCast([]const u8, contents);
fn u8SliceHelper(comptime T: type, ptr: anytype) []const u8 {
    const info = @typeInfo(@TypeOf(ptr)).Pointer;
    switch (info.size) {
        .Slice => {
            const size = ptr.len * @sizeOf(T);
            const u8_ptr = @ptrCast([*]const u8, ptr.ptr);
            return u8_ptr[0..size];
        },
        .One => {
            const size = @sizeOf(T);
            const u8_ptr = @ptrCast([*]const u8, ptr);
            return u8_ptr[0..size];
        },
        else => {
            @compileError("Many and C pointers cannot be cast to concrete slices, found: " ++ @typeName(@TypeOf(ptr)));
        },
    }
}

pub fn VertexBuffer(comptime Vertex: type) type {
    return struct {
        const Self = @This();

        buffer: c.WGPUBuffer,
        size: usize,
        vertex_count: usize,

        pub fn init(graphics: *const wgpu.Graphics, contents: []const Vertex) Self {
            const buffer = createBuffer(
                graphics,
                u8SliceHelper(Vertex, contents),
                "vertex buffer",
                .vertex,
            );

            return Self{
                .buffer = buffer,
                .size = contents.len * @sizeOf(Vertex),
                .vertex_count = contents.len,
            };
        }

        pub fn deinit(self: *const Self) void {
            c.wgpuBufferDestroy(self.buffer);
        }

        pub fn layout() c.WGPUVertexBufferLayout {
            return vertexBufferLayout(Vertex);
        }
    };
}

pub fn UniformBuffer(comptime Value: type) type {
    return struct {
        const Self = @This();

        graphics: *const wgpu.Graphics,
        buffer: c.WGPUBuffer,
        bind_group_layout: c.WGPUBindGroupLayout,
        bind_group: c.WGPUBindGroup,

        pub fn init(graphics: *const wgpu.Graphics, contents: Value) Self {
            const bind_group_layout = c.wgpuDeviceCreateBindGroupLayout(
                graphics.device,
                &c.WGPUBindGroupLayoutDescriptor{
                    .nextInChain = null,
                    .label = "bind group layout",
                    .entryCount = 1,
                    .entries = &[1]c.WGPUBindGroupLayoutEntry{
                        zeroInit(c.WGPUBindGroupLayoutEntry, .{
                            .binding = 0,
                            .visibility = c.WGPUShaderStage_Vertex,
                            .buffer = c.WGPUBufferBindingLayout{
                                .nextInChain = null,
                                .type = c.WGPUBufferBindingType_Uniform,
                                .hasDynamicOffset = false,
                                .minBindingSize = 0,
                            },
                        }),
                    },
                },
            );

            const buffer = createBuffer(
                graphics,
                u8SliceHelper(Value, &contents),
                "uniform buffer",
                .uniform,
            );

            const bind_group = c.wgpuDeviceCreateBindGroup(
                graphics.device,
                &c.WGPUBindGroupDescriptor{
                    .nextInChain = null,
                    .label = "bind group",
                    .layout = bind_group_layout,
                    .entryCount = 1,
                    .entries = &[1]c.WGPUBindGroupEntry{
                        zeroInit(c.WGPUBindGroupEntry, .{
                            .binding = 0,
                            .buffer = buffer,
                            .offset = 0,
                            .size = @sizeOf(Value),
                        }),
                    },
                },
            );

            return Self{
                .graphics = graphics,
                .buffer = buffer,
                .bind_group_layout = bind_group_layout,
                .bind_group = bind_group,
            };
        }

        pub fn deinit(self: *const Self) void {
            c.wgpuBufferDestroy(self.buffer);
        }

        pub fn write(self: *const Self, value: Value) void {
            c.wgpuQueueWriteBuffer(
                self.graphics.queue,
                self.buffer,
                0,
                @ptrCast([*]const u8, &value),
                @sizeOf(Value),
            );
        }
    };
}
