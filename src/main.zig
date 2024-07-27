const std = @import("std");
const c = @import("clibs.zig");
const gen_arena = @import("gen_arena.zig");
const ecs = @import("ecs/ecs.zig");
const ComponentBegin = ecs.ComponentBegin;
const ComponentUpdate = ecs.ComponentUpdate;
const ComponentDestroyed = ecs.ComponentDestroyed;
const window = @import("engine/window.zig");
const sdl_util = @import("sdl_util.zig");
const engine = @import("engine/engine.zig");

const math = @import("math/main.zig");
const Vec2 = math.Vec2;
const Rect2 = math.Rect2;
const vec2 = math.vec2;

const TextureHandle = engine.TextureHandle;
const Engine = engine.Engine;
const EntityID = ecs.EntityID;
const ComponentHandle = ecs.ComponentHandle;

const SDL = @import("clibs.zig");

const World = ecs.World;

var rand_gen: std.Random = undefined;
var running: bool = true;

const FlappyGame = struct {
    pub fn init(self: *FlappyGame, engine_inst: *engine.Engine) anyerror!void {
        _ = self;
        var bird_entity = try engine_inst.world.new_entity();
        try bird_entity.add_component(Bird{});

        var pipe_manager = try engine_inst.world.new_entity();
        try pipe_manager.add_component(PipeManager.new(bird_entity.id()));
    }
    pub fn update(self: *FlappyGame, engine_inst: *engine.Engine, delta_seconds: f64) anyerror!void {
        _ = self;
        _ = engine_inst;
        _ = delta_seconds;
    }
    pub fn end(self: *FlappyGame, engine_inst: *engine.Engine) anyerror!void {
        _ = self;
        _ = engine_inst;
    }
};

const Bird = struct {
    const SPEED: f32 = 100.0;
    bird_texture: TextureInfo = undefined,
    velocity: Vec2 = Vec2.ZERO,
    pos: Vec2 = Vec2.ZERO,
    rot: f32 = 0.0,

    pub fn begin(this: *Bird, ctx: ComponentBegin) anyerror!void {
        this.bird_texture = try load_texture_from_file(ctx.world.engine(), "./assets/apple.png");
    }

    pub fn update(this: *Bird, ctx: ComponentUpdate) anyerror!void {
        var renderer = &ctx.world.engine().renderer;
        if (engine.Input.is_key_just_down(SDL.SDL_SCANCODE_R)) {
            this.pos = Vec2.ZERO;
            this.velocity = Vec2.ZERO;
            running = true;
        }
        if (engine.Input.is_key_down(c.SDL_SCANCODE_SPACE) and running) {
            this.velocity.set_y(-5.0);
        }

        this.velocity.set_y(this.velocity.y() + @as(f32, @floatCast(ctx.delta_time)) * 10.0);
        this.pos = this.pos.add(this.velocity);

        if (this.pos.y() < -400.0 or this.pos.y() > 400.0) {
            this.pos.set_y(std.math.clamp(this.pos.y(), -400.0, 400.0));
            running = false;
        }

        try renderer.draw_texture(engine.renderer.TextureDrawInfo{
            .texture = this.bird_texture.handle,
            .position = this.pos,
            .rotation = this.rot,
            .scale = Vec2.ONE,
            .region = Rect2{
                .offset = Vec2.ZERO,
                .extent = this.bird_texture.extents,
            },
            .z_index = -5,
        });
    }
    pub fn destroyed(self: *Bird, ctx: ComponentDestroyed) anyerror!void {
        ctx.world.engine().renderer.free_texture(self.bird_texture.handle);
    }
};

const Pipe = struct {
    pos: Vec2 = Vec2.ZERO,
    hit: bool = false,
};
const PipeManager = struct {
    const PIPE_HEIGHT: f32 = 600.0;
    const PIPE_WIDTH: f32 = 30.0;
    const PIPE_GAP: f32 = 200.0;
    const PIPE_SPEED: f32 = 300.0;
    const PIPE_DIST: f32 = 300.0;
    pipes: [5]Pipe = .{
        .{},
        .{},
        .{},
        .{},
        .{},
    },
    player: EntityID,
    bird: ComponentHandle(Bird) = undefined,

    fn new(player: EntityID) PipeManager {
        return .{
            .player = player,
        };
    }

    pub fn begin(this: *PipeManager, ctx: ComponentBegin) anyerror!void {
        try this.init();
        this.bird = ctx.world.get_component(Bird, this.player).?;
    }

    fn init(this: *PipeManager) !void {
        for (&this.pipes, 0..) |*pipe, i| {
            try reset_pipe(pipe, @intCast(i));
        }
    }

    fn reset_pipe(pipe: *Pipe, index_mult: u32) !void {
        pipe.pos.set_x(700.0 + @as(f32, @floatFromInt(index_mult)) * PIPE_DIST);
        const y = 160.0 * rand_gen.float(f32);
        pipe.pos.set_y(y);
        pipe.hit = false;
    }

    pub fn update(this: *PipeManager, ctx: ComponentUpdate) !void {
        const player_pos = this.bird.get().pos;
        const delta_secs = ctx.delta_time;
        var engine_inst = ctx.world.engine();
        for (&this.pipes) |*pipe| {
            if (running) {
                pipe.pos.set_x(pipe.pos.x() - PIPE_SPEED * @as(f32, @floatCast(delta_secs)));
                if (pipe.pos.x() <= -(600.0 + 2.0 * PIPE_WIDTH)) {
                    try reset_pipe(pipe, 0);
                }
            }

            const rect_1 = Rect2{
                .offset = vec2(pipe.pos.x(), pipe.pos.y() + (PIPE_HEIGHT + PIPE_GAP) * 0.5),
                .extent = vec2(PIPE_WIDTH, PIPE_HEIGHT),
            };

            const rect_2 = Rect2{
                .offset = vec2(pipe.pos.x(), pipe.pos.y() - (PIPE_HEIGHT + PIPE_GAP) * 0.5),
                .extent = vec2(PIPE_WIDTH, PIPE_HEIGHT),
            };

            const gap_rect = Rect2{
                .offset = vec2(pipe.pos.x(), pipe.pos.y() - PIPE_GAP * 0.5),
                .extent = vec2(PIPE_WIDTH, PIPE_HEIGHT),
            };

            var color_1 = math.vec4(0.0, 1.0, 0.0, 1.0);
            var color_2 = math.vec4(0.0, 1.0, 0.0, 1.0);

            if (rect_1.intersects(Rect2{
                .offset = player_pos,
                .extent = vec2(32.0, 32.0),
            })) {
                color_1 = math.vec4(1.0, 0.0, 0.0, 1.0);
                running = false;
            }
            if (rect_2.intersects(Rect2{
                .offset = player_pos,
                .extent = vec2(32.0, 32.0),
            })) {
                color_2 = math.vec4(1.0, 0.0, 0.0, 1.0);
                running = false;
            }

            if (running and gap_rect.intersects(Rect2{
                .offset = player_pos,
                .extent = vec2(32.0, 32.0),
            }) and !pipe.hit) {
                std.debug.print("Point!\n", .{});
                pipe.hit = true;
            }

            var renderer = &engine_inst.renderer;
            try renderer.draw_rect(engine.renderer.RectDrawInfo{
                .color = color_1,
                .rect = rect_1,
            });

            try renderer.draw_rect(engine.renderer.RectDrawInfo{
                .color = color_2,
                .rect = rect_2,
            });
        }
    }
};

const TextureInfo = struct {
    handle: TextureHandle,
    extents: Vec2,
};

fn load_texture_from_file(inst: *engine.Engine, path: []const u8) anyerror!TextureInfo {
    var width: c_int = undefined;
    var height: c_int = undefined;
    var channels: c_int = undefined;

    const data_p = SDL.stbi_load(path.ptr, &width, &height, &channels, 4);
    std.debug.assert(data_p != null);
    defer SDL.stbi_image_free(data_p);
    const data_size = width * height * channels;
    const format = switch (channels) {
        4 => engine.renderer.TextureFormat.rgba_8,
        else => unreachable,
    };
    const data = data_p[0..@intCast(data_size)];

    const handle = try inst.renderer.alloc_texture(engine.Texture.CreateInfo{
        .width = @intCast(width),
        .height = @intCast(height),
        .format = format,
        .initial_bytes = data,
        .sampler_config = engine.renderer.SamplerConfig.NEAREST,
    });

    return TextureInfo{
        .handle = handle,
        .extents = vec2(@floatFromInt(width), @floatFromInt(height)),
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var rand = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    rand_gen = rand.random();

    var engine_instance = try engine.Engine.init(.{
        .width = 800,
        .height = 1200,
        .name = "Flappy Game",
    }, allocator);
    defer engine_instance.deinit();

    var game = FlappyGame{};
    try engine_instance.run_loop(engine.Game.make(FlappyGame, &game));
}
