const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const FPS = 60;
const DELTA_TIME_SEC: f32 = 1.0/@intToFloat(f32, FPS);
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const PROJ_SIZE: f32 = 25*0.80;
const PROJ_SPEED: f32 = 400;
const BAR_LEN: f32 = 100;
const BAR_THICCNESS: f32 = PROJ_SIZE;
const BAR_Y: f32 = WINDOW_HEIGHT - BAR_THICCNESS - 50;
const BAR_SPEED: f32 = PROJ_SPEED*1.5;
const TARGET_WIDTH = BAR_LEN;
const TARGET_HEIGHT = BAR_THICCNESS;
const TARGET_PADDING_X = 20;
const TARGET_PADDING_Y = 50;
const TARGET_ROWS = 4;
const TARGET_COLS = 5;
const TARGET_GRID_WIDTH = (TARGET_COLS*TARGET_WIDTH + (TARGET_COLS - 1)*TARGET_PADDING_X);
const TARGET_GRID_X = WINDOW_WIDTH/2 - TARGET_GRID_WIDTH/2;
const TARGET_GRID_Y = 50;

const Target = struct {
    x: f32,
    y: f32,
    dead: bool = false,
};

fn init_targets() [TARGET_ROWS*TARGET_COLS]Target {
    var targets: [TARGET_ROWS*TARGET_COLS]Target = undefined;
    var row: usize = 0;
    while (row < TARGET_ROWS) : (row += 1) {
        var col: usize = 0;
        while (col < TARGET_COLS) : (col += 1) {
            targets[row*TARGET_COLS + col] = Target {
                .x = TARGET_GRID_X + (TARGET_WIDTH + TARGET_PADDING_X)*@intToFloat(f32, col),
                .y = TARGET_GRID_Y + TARGET_PADDING_Y*@intToFloat(f32, row)
            };
        }
    }
    return targets;
}

var targets_pool = init_targets();
var bar_x:   f32 = WINDOW_WIDTH/2 - BAR_LEN/2;
var bar_dx:  f32 = 0;
var proj_x:  f32 = WINDOW_WIDTH/2 - PROJ_SIZE/2;
var proj_y:  f32 = BAR_Y - BAR_THICCNESS/2 - PROJ_SIZE;
var proj_dx: f32 = 1;
var proj_dy: f32 = 1;
var quit = false;
var pause = false;
var started = false;
// TODO: death
// TODO: score

fn make_rect(x: f32, y: f32, w: f32, h: f32) c.SDL_Rect {
    return c.SDL_Rect {
        .x = @floatToInt(i32, x),
        .y = @floatToInt(i32, y),
        .w = @floatToInt(i32, w),
        .h = @floatToInt(i32, h)
    };
}

fn target_rect(target: Target) c.SDL_Rect {
    return make_rect(target.x, target.y, TARGET_WIDTH, TARGET_HEIGHT);
}

fn proj_rect(x: f32, y: f32) c.SDL_Rect {
    return make_rect(x, y, PROJ_SIZE, PROJ_SIZE);
}

fn bar_rect() c.SDL_Rect {
    return make_rect(bar_x, BAR_Y - BAR_THICCNESS/2, BAR_LEN, BAR_THICCNESS);
}

fn update(dt: f32) void {
    const overlaps = c.SDL_HasIntersection;

    if (!pause and started) {
        bar_x = math.clamp(bar_x + bar_dx*BAR_SPEED*dt, 0, WINDOW_WIDTH - BAR_LEN);

        var proj_nx = proj_x + proj_dx*PROJ_SPEED*dt;
        var cond_x = proj_nx < 0 or
            proj_nx + PROJ_SIZE > WINDOW_WIDTH or
            overlaps(&proj_rect(proj_nx, proj_y), &bar_rect()) != 0;
        for (targets_pool) |*target| {
            if (cond_x) break;
            if (!target.dead) {
                cond_x = cond_x or overlaps(&proj_rect(proj_nx, proj_y), &target_rect(target.*)) != 0;
                if (cond_x) target.dead = true;
            }
        }
        if (cond_x) {
            proj_dx *= -1;
            proj_nx = proj_x + proj_dx*PROJ_SPEED*dt;
        }
        proj_x = proj_nx;

        var proj_ny = proj_y + proj_dy*PROJ_SPEED*dt;
        var cond_y = proj_ny < 0 or proj_ny + PROJ_SIZE > WINDOW_HEIGHT;
        if (!cond_y) {
            cond_y = cond_y or overlaps(&proj_rect(proj_x, proj_ny), &bar_rect()) != 0;
            if (cond_y and bar_dx != 0) proj_dx = bar_dx;
        }
        for (targets_pool) |*target| {
            if (cond_y) break;
            if (!target.dead) {
                cond_y = cond_y or overlaps(&proj_rect(proj_x, proj_ny), &target_rect(target.*)) != 0;
                if (cond_y) target.dead = true;
            }
        }
        if (cond_y) {
            proj_dy *= -1;
            proj_ny = proj_y + proj_dy*PROJ_SPEED*dt;
        }
        proj_y = proj_ny;
    }
}

fn render(renderer: *c.SDL_Renderer) void {
    _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
    _ = c.SDL_RenderFillRect(renderer, &proj_rect(proj_x, proj_y));

    _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0, 0, 0xFF);
    _ = c.SDL_RenderFillRect(renderer, &bar_rect());

    _ = c.SDL_SetRenderDrawColor(renderer, 0, 0xFF, 0, 0xFF);
    for (targets_pool) |target| {
        if (!target.dead) {
            _ = c.SDL_RenderFillRect(renderer, &target_rect(target));
        }
    }
}

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Zigout", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, 0) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    const keyboard = c.SDL_GetKeyboardState(null);

    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_KEYDOWN => switch (event.key.keysym.sym) {
                    ' ' => { pause = !pause; },
                    else => {},
                },
                else => {},
            }
        }

        bar_dx = 0;
        if (keyboard[c.SDL_SCANCODE_A] != 0) {
            bar_dx += -1;
            if (!started) {
                started = true;
                proj_dx = -1;
            }
        }
        if (keyboard[c.SDL_SCANCODE_D] != 0) {
            bar_dx += 1;
            if (!started) {
                started = true;
                proj_dx = 1;
            }
        }

        update(DELTA_TIME_SEC);

        _ = c.SDL_SetRenderDrawColor(renderer, 0x18, 0x18, 0x18, 0xFF);
        _ = c.SDL_RenderClear(renderer);

        render(renderer);

        c.SDL_RenderPresent(renderer);

        c.SDL_Delay(1000/FPS);
    }
}
