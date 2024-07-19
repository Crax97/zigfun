const std = @import("std");
const SDL = @import("sdl2");
const sdl_panic = @import("sdl_util.zig").sdl_panic;

pub const WindowConfig = struct {
    name: []const u8 = "Game",
    width: u32 = 800,
    height: u32 = 600,
};

pub const Window = struct {
    window: *SDL.SDL_Window,

    pub fn init(window_config: WindowConfig) Window {
        const width: c_int = @intCast(window_config.width);
        const height: c_int = @intCast(window_config.height);
        const sdl_win = SDL.SDL_CreateWindow(window_config.name.ptr, SDL.SDL_WINDOWPOS_CENTERED, SDL.SDL_WINDOWPOS_CENTERED, width, height, SDL.SDL_WINDOW_VULKAN | SDL.SDL_WINDOW_SHOWN) orelse {
            return sdl_panic();
        };

        return .{ .window = sdl_win };
    }

    pub fn deinit(this: *Window) void {
        SDL.SDL_DestroyWindow(this.window);
    }
};