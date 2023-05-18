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

pub const Buffer = struct {
    buffer: c.WGPUBuffer,
    vertex_count: usize,
    size: usize,

    pub const Usage = enum {
        vertex,
        uniform,
    };

    pub fn init(
        graphics: *wgpu.Graphics,
        contents: anytype,
        label: ?[]const u8,
        usage: Usage,
    ) !Buffer {
        const contents_T = @TypeOf(contents);
        const contents_info = @typeInfo(contents_T);

        comptime var T: type = undefined;
        var vertex_count: usize = 1;

        switch (contents_info) {
            .Pointer => |info| {
                T = info.child;

                if (info.size == .Slice) {
                    vertex_count = contents.len;
                } else if (info.size == .One) {
                    const ptr_info = @typeInfo(T);
                    switch (ptr_info) {
                        .Array => |array| {
                            vertex_count = array.len;
                            T = array.child;
                        },
                        else => {},
                    }
                } else {
                    @compileError("WGPU Buffers cannot be initialized with [*] or [*c] pointers, found " ++ @typeName(contents_T));
                }
            },
            else => {
                T = contents_T;
            },
        }

        const size = vertex_count * @sizeOf(T);

        const buffer_usage: u32 = switch (usage) {
            .vertex => c.WGPUBufferUsage_Vertex,
            .uniform => c.WGPUBufferUsage_Uniform | c.WGPUBufferUsage_CopyDst,
        };

        const wgpu_buffer = c.wgpuDeviceCreateBuffer(
            graphics.device,
            &c.WGPUBufferDescriptor{
                .size = size,
                .label = if (label) |l| l.ptr else null,
                .usage = buffer_usage,
                .mappedAtCreation = true,
                .nextInChain = null,
            },
        );

        const data_opaque = c.wgpuBufferGetMappedRange(wgpu_buffer, 0, size);
        const data = @ptrCast([*]T, @alignCast(@alignOf(T), data_opaque));

        // @compileLog("T is " ++ @typeName(T));

        if (contents_info == .Pointer) {
            @memcpy(data[0..vertex_count], contents);
        } else {
            data[0] = contents;
        }
        c.wgpuBufferUnmap(wgpu_buffer);

        return Buffer{
            .buffer = wgpu_buffer,
            .vertex_count = vertex_count,
            .size = size,
        };
    }

    pub fn deinit(self: *const Buffer) void {
        c.wgpuBufferDestroy(self.buffer);
    }
};
