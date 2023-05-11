const std = @import("std");
const buffer = @import("buffer.zig");

const Vertex = extern struct {
    position: [3]f32,
    color: [3]f32,
};
