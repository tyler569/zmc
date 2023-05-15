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
        print("Error: Vertex buffers must consist of extern structs, found " ++ @typeName(T) ++ "\n", .{});
        return error.VertexBufferWithNonStruct;
    }

    const struct_info = info.Struct;

    if (struct_info.layout != .Extern) {
        print("Error: Vertex buffers must consist of extern structs, found " ++ @typeName(T) ++ "\n", .{});
        return error.VertexBufferWithNonExternStruct;
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

        pub fn bufferLayout() c.WGPUVertexBufferLayout {
            return bufferLayout(T);
        }

        fn deinit(self: *Self) void {
            _ = self;
            std.debug.print("deinit Buffer\n", .{});
        }
    };
}
