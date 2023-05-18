const std = @import("std");
const sdl = @import("sdl.zig");
const wgpu = @import("wgpu.zig");
const buffer = @import("buffer.zig");
const mesh = @import("mesh.zig");

pub fn main() !void {
    try sdl.init();
    var window = try sdl.Window.create("Triangle", 640, 480);
    var graphics = try wgpu.init(&window);

    const v_buffer = try graphics.createVertexBufferInit(
        mesh.Vertex,
        &mesh.sample_mesh,
    );
    defer v_buffer.deinit();

    const u_buffer = try graphics.createUniformBufferInit(f32, 1.0);
    defer u_buffer.deinit();

    var pipeline = try graphics.createPipeline(.{v_buffer}, .{u_buffer});

    const frame_ns = std.time.ns_per_s / 60;
    const start = std.time.milliTimestamp();

    while (window.pollEvents() != .quit) {
        const color = wgpu.Color{ .r = 0.1, .g = 0.2, .b = 0.3, .a = 1.0 };

        var frame = try graphics.render();
        defer frame.finish() catch unreachable;

        {
            var pass = try frame.renderPass(&pipeline, wgpu.RenderOp{ .clear = color });

            try pass.attachBuffer(v_buffer);
            try pass.attachUniform(u_buffer);
            try pass.draw();
        }

        u_buffer.write(@intToFloat(f32, std.time.milliTimestamp() - start) / 1000.0);

        std.time.sleep(frame_ns);
    }
}
