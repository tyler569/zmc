const std = @import("std");
const sdl = @import("sdl.zig");
const wgpu = @import("wgpu.zig");

pub fn main() !void {
    try sdl.init();
    const window = try sdl.Window.create("Minecraft", 640, 480);
    const graphics = try wgpu.init(&window);

    std.debug.print("window: {}\ngraphics: {}\n", .{ window, graphics });

    window.pollEventsForever();
}
