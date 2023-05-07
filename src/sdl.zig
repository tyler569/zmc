const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const Event = c.SDL_Event;
pub const NativeLayer = opaque {};

pub fn init() !void {
    const result = c.SDL_Init(c.SDL_INIT_VIDEO);
    if (result < 0) {
        return error.SDLInitFailed;
    }
}

pub const Window = struct {
    window: ?*c.SDL_Window = null,
    surface: ?*c.SDL_Surface = null,
    renderer: ?*c.SDL_Renderer = null,

    pub fn create(name: [*c]const u8, x: i32, y: i32) !Window {
        const window = c.SDL_CreateWindow(
            name,
            c.SDL_WINDOWPOS_UNDEFINED,
            c.SDL_WINDOWPOS_UNDEFINED,
            x,
            y,
            c.SDL_WINDOW_SHOWN,
        ) orelse return error.CreateWindowFailed;

        const surface = c.SDL_GetWindowSurface(window) orelse return error.WindowSurfaceFailed;
        const renderer = c.SDL_GetRenderer(window) orelse return error.WindowRendererFailed;

        return Window{
            .window = window,
            .surface = surface,
            .renderer = renderer,
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
                    if (event.key.keysym.scancode == 41) {
                        self.destroy();
                        return;
                    }
                },
                else => {
                    // std.debug.print("event: {}\n", .{event.type});
                },
            }
        }
    }

    pub fn nativeLayer(self: *const Window) ?*NativeLayer {
        const layer = c.SDL_RenderGetMetalLayer(self.renderer);
        return @ptrCast(?*NativeLayer, layer);
    }
};
