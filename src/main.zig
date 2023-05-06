const std = @import("std");
const sdl = @import("sdl.zig");

pub fn main() !void {
    try sdl.init();
    const window = try sdl.Window.create("Minecraft", 640, 480);
    window.pollEventsForever();
}


