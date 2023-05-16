const std = @import("std");
const print = std.debug.print;
const expectEqual = std.testing.expectEqual;

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
            print("Error: No definition for value of type " ++ @typeName(T) ++ " in Vertex\n", .{});
            return error.InvalidVertexField;
        },
    };
}

pub fn vertexBufferLayout(comptime T: type) !c.WGPUVertexBufferLayout {
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

    try error.Ooops;
}

pub fn Buffer(comptime T: type) type {
    return struct {
        const Self = @This();

        buffer: c.WGPUBuffer,
        vertex_count: usize,
        size: usize,

        pub fn bufferLayout() c.WGPUVertexBufferLayout {
            return bufferLayout(T);
        }

        pub fn init(graphics: *wgpu.Graphics, contents: []const T, label: ?[]const u8) !Self {
            const size = contents.len * @sizeOf(T);

            const wgpu_buffer = c.wgpuDeviceCreateBuffer(
                graphics.device,
                &c.WGPUBufferDescriptor{
                    .size = size,
                    .label = if (label) |l| l.ptr else null,
                    .usage = c.WGPUBufferUsage_Vertex,
                    .mappedAtCreation = true,
                    .nextInChain = null,
                },
            );

            const data_opaque = c.wgpuBufferGetMappedRange(wgpu_buffer, 0, size);
            const data = @ptrCast([*]T, @alignCast(@alignOf(T), data_opaque));

            @memcpy(data[0..contents.len], contents);
            c.wgpuBufferUnmap(wgpu_buffer);

            return Self{
                .buffer = wgpu_buffer,
                .vertex_count = contents.len,
                .size = size,
            };
        }

        pub fn deinit(self: *Self) void {
            _ = self;
            std.debug.print("deinit Buffer\n", .{});
        }
    };
}
