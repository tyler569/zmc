const std = @import("std");
const buffer = @import("buffer.zig");

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
