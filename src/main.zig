const std = @import("std");
const sdl = @import("sdl.zig");
const wgpu = @import("wgpu.zig");
const buffer = @import("buffer.zig");

pub fn main() !void {
    try sdl.init();
    var window = try sdl.Window.create("Triangle", 640, 480);
    var graphics = try wgpu.init(&window);
    var pipeline = try graphics.createPipeline();

    // std.debug.print("window: {}\ngraphics: {}\n", .{ window, graphics });

    const vertex_struct = extern struct {
        const Self = @This();

        a: [2]f32,

        fn new(a: f32, b: f32) Self {
            return .{ .a = [2]f32{ a, b } };
        }
    };

    const vertex_data = [_]vertex_struct{
        vertex_struct.new(1.0, 2.0),
        vertex_struct.new(1.0, 2.0),
    };

    const v_buffer = try graphics.createVertexBufferInit(vertex_struct, "vertex", &vertex_data);
    _ = v_buffer;

    const frame_ns = std.time.ns_per_s / 60;

    while (window.pollEvents() != .quit) {
        try graphics.renderPass(pipeline);
        std.time.sleep(frame_ns);
    }
}
