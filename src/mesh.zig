const std = @import("std");
const buffer = @import("buffer.zig");
const wgpu = @import("wgpu.zig");

pub const Vertex = extern struct {
    position: [3]f32,
    color: [4]f32,
};

const RED = [4]f32{ 1.0, 0.0, 0.0, 1.0 };
const GREEN = [4]f32{ 0.0, 1.0, 0.0, 1.0 };
const BLUE = [4]f32{ 0.0, 0.0, 1.0, 1.0 };
const BLACK = [4]f32{ 0.0, 0.0, 0.0, 1.0 };

const A = Vertex{ .position = .{ -0.5, -0.5, 0 }, .color = BLUE };
const B = Vertex{ .position = .{ -0.5, 0.5, 0 }, .color = RED };
const C = Vertex{ .position = .{ 0.5, 0.5, 0 }, .color = GREEN };
const D = Vertex{ .position = .{ 0.5, -0.5, 0 }, .color = BLUE };

pub const sample_mesh = [6]Vertex{
    A, C, B,
    A, D, C,
};

pub const Chunk = struct {
    const x_size: usize = 16;
    const y_size: usize = 384;
    const z_size: usize = 16;

    data: [x_size][y_size][z_size]u16 = undefined,

    pub fn default() Chunk {
        var chunk = Chunk{};

        for (0..x_size) |x| {
            for (0..y_size) |y| {
                for (0..z_size) |z| {
                    chunk.data[x][y][z] = 0;
                }
            }
        }

        for (0..x_size) |x| {
            for (0..16) |y| {
                for (0..z_size) |z| {
                    chunk.data[x][y][z] = 1;
                }
            }
        }

        return chunk;
    }

    const Direction = enum {
        north,
        south,
        east,
        west,
        up,
        down,
    };

    const ChunkMesh = struct {
        vertices: std.ArrayList(Vertex),

        fn init(allocator: std.mem.Allocator) ChunkMesh {
            return ChunkMesh{
                .vertices = std.ArrayList(Vertex).init(allocator),
            };
        }

        fn emitFace(x: usize, y: usize, z: usize, face: Direction) !void {
            _ = x;
            _ = y;
            _ = z;
            _ = face;
        }

        fn finish(
            self: *ChunkMesh,
            graphics: *wgpu.Graphics,
        ) !buffer.VertexBuffer(Vertex) {
            const buf = graphics.createVertexBufferInit(
                Vertex,
                self.vertices.items,
            );
            self.vertices.deinit();
            return buf;
        }
    };

    pub fn generateMesh(
        self: Chunk,
        graphics: *wgpu.Graphics,
        allocator: std.mem.Allocator,
    ) !buffer.VertexBuffer(Vertex) {
        var meshGen = ChunkMesh.init(allocator);

        for (0..x_size) |x| {
            for (0..y_size) |y| {
                for (0..z_size) |z| {
                    if (self.data[x][y][z] != 0)
                        meshGen.emitFace(x, y, z, .north);
                }
            }
        }

        return meshGen.finish(graphics);
    }
};
