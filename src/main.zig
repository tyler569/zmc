const std = @import("std");
const sdl = @import("sdl.zig");
const wgpu = @import("wgpu.zig");

pub fn main() !void {
    try sdl.init();
    var window = try sdl.Window.create("Minecraft", 640, 480);
    var graphics = try wgpu.init(&window);
    var pipeline = try graphics.createPipeline();

    std.debug.print("window: {}\ngraphics: {}\n", .{ window, graphics });

    const frame_ns = std.time.ns_per_s / 60;

    while (window.pollEvents() != .quit) {
        try graphics.renderPass(pipeline);
        std.time.sleep(frame_ns);
    }
}
