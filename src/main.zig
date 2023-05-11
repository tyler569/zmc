const std = @import("std");
const sdl = @import("sdl.zig");
const wgpu = @import("wgpu.zig");
const buffer = @import("buffer.zig");

fn test_buffer() !void {
    const Vertex = extern struct {
        position: [3]f32,
        color: [4]f32,
    };

    const buffer_layout = try buffer.vertexBufferLayout(Vertex);
    std.debug.print("{}\n", .{buffer_layout});
    for (0..buffer_layout.attributeCount) |i| {
        std.debug.print("{}\n", .{buffer_layout.attributes[i]});
    }
}

pub fn main() !void {
    try sdl.init();
    var window = try sdl.Window.create("Triangle", 640, 480);
    var graphics = try wgpu.init(&window);
    var pipeline = try graphics.createPipeline();

    // std.debug.print("window: {}\ngraphics: {}\n", .{ window, graphics });A
    test_buffer() catch unreachable;

    const frame_ns = std.time.ns_per_s / 60;

    while (window.pollEvents() != .quit) {
        try graphics.renderPass(pipeline);
        std.time.sleep(frame_ns);
    }
}
