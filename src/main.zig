const std = @import("std");
const sdl = @import("sdl.zig");
const wgpu = @import("wgpu.zig");
const buffer = @import("buffer.zig");
const mesh = @import("mesh.zig");

pub fn main() !void {
    try sdl.init();
    var window = try sdl.Window.create("Triangle", 640, 480);
    var graphics = try wgpu.init(&window);
    var pipeline = try graphics.createPipeline(mesh.Vertex);

    const v_buffer = try graphics.createVertexBufferInit(
        mesh.Vertex,
        "vertex",
        &mesh.sample_mesh,
    );
    defer v_buffer.deinit();

    const frame_ns = std.time.ns_per_s / 60;

    while (window.pollEvents() != .quit) {
        const color = wgpu.Color{ .r = 0.1, .g = 0.2, .b = 0.3, .a = 1.0 };

        var frame = try graphics.render();
        var pass = try frame.renderPass(&pipeline, wgpu.RenderOp{ .clear = color });

        try pass.attachBuffer(v_buffer);
        try pass.draw();
        try frame.finish();

        std.time.sleep(frame_ns);
    }
}
