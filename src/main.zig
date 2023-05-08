const std = @import("std");
const sdl = @import("sdl.zig");
const wgpu = @import("wgpu.zig");

pub fn main() !void {
    try sdl.init();
    var window = try sdl.Window.create("Minecraft", 640, 480);
    var graphics = try wgpu.init(&window);

    var pipeline = try graphics.createPipeline();
    _ = pipeline;

    std.debug.print("window: {}\ngraphics: {}\n", .{ window, graphics });

    window.pollEventsForever();
}
