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

    const TransformMatrix = struct {
        matrix: [16]f32,

        pub fn identity() @This() {
            return @This(){
                .matrix = [16]f32{
                    1, 0, 0, 0,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1,
                },
            };
        }
    };

    const v_buffer = try graphics.createVertexBufferInit(
        mesh.Vertex,
        &mesh.sample_mesh,
    );
    defer v_buffer.deinit();

    const u_buffer = try graphics.createUniformBufferInit(
        TransformMatrix,
        TransformMatrix.identity(),
    );
    defer u_buffer.deinit();

    const frame_ns = std.time.ns_per_s / 60;

    {
        const linear = @import("linear.zig");

        const v1 = linear.Vec4{ .x = 1.0, .y = 2.0, .z = 3.0, .w = 4.0 };
        const v2 = v1;

        const v3 = v1.add(v2);

        std.debug.print("{} +\n{} =\n{}\n", .{ v1, v2, v3 });

        std.debug.print("lengths: {} {} {}\n", .{ v1.length(), v2.length(), v3.length() });
    }

    while (window.pollEvents() != .quit) {
        const color = wgpu.Color{ .r = 0.1, .g = 0.2, .b = 0.3, .a = 1.0 };

        var frame = try graphics.render();
        defer frame.finish() catch unreachable;

        {
            var pass = try frame.renderPass(&pipeline, wgpu.RenderOp{ .clear = color });

            try pass.attachBuffer(v_buffer);
            try pass.draw();
        }

        std.time.sleep(frame_ns);
    }
}
