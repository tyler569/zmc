const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const Event = c.SDL_Event;

pub fn init() !void {
    const result = c.SDL_Init(c.SDL_INIT_VIDEO);
    if (result < 0) {
        return error.SDLInitFailed;
    }
}

pub const Window = struct {
    window: ?*c.SDL_Window = null,
    surface: ?* c.SDL_Surface = null,

    pub fn create(name: [*c]const u8, x: i32, y: i32) !Window {
        const window = c.SDL_CreateWindow(
            name,
            c.SDL_WINDOWPOS_UNDEFINED,
            c.SDL_WINDOWPOS_UNDEFINED,
            x,
            y,
            c.SDL_WINDOW_SHOWN,
        ) orelse return error.CreateWindowFailed;

        const surface = c.SDL_GetWindowSurface(window);

        return Window {
            .window = window,
            .surface = surface,
        };
    }

    pub fn destroy(self: Window) void {
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    pub fn pollEventsForever(self: Window) void {
        var event: Event = undefined;
    
        while (true) {
            _ = c.SDL_WaitEvent(&event);

            switch (event.type) {
                c.SDL_QUIT => {
                    self.destroy();
                    return;
                },
                c.SDL_KEYDOWN => {
                    std.debug.print("keydown: {}\n", .{event.key});
                },
                else => {
                    // std.debug.print("event: {}\n", .{event.type});
                },
            }
        }
    }
};


