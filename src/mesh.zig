const std = @import("std");
const buffer = @import("buffer.zig");

pub const Vertex = extern struct {
    position: [3]f32,
    color: [4]f32,
};

pub const sample_mesh: [3]Vertex = [3]Vertex{
    .{ .position = .{ -0.5, -0.5, 0 }, .color = .{ 1.0, 0.0, 0.0, 1.0 } },
    .{ .position = .{ 0.0, 0.5, 0 }, .color = .{ 0.0, 1.0, 0.0, 1.0 } },
    .{ .position = .{ 0.5, -0.5, 0 }, .color = .{ 1.0, 0.0, 0.0, 1.0 } },
};
