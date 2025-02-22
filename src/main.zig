const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const Gol = @import("game-of-life.zig");

const Color = rl.Color;
const Vec2 = rl.Vector2;
const Rect = rl.Rectangle;

var screen_width: i32 = 800;
var screen_height: i32 = 500;

const panel_width = 250;

pub fn main() !void {
    rl.initWindow(screen_width, screen_height, "Game of Life");
    defer rl.closeWindow();
    rl.setWindowState(.{ .window_resizable = true });

    rl.setTargetFPS(60);

    var sidebar_rect = Rect.init(
        @floatFromInt(screen_width - panel_width),
        0,
        @floatFromInt(panel_width),
        @floatFromInt(screen_height),
    );

    var camera = rl.Camera2D{
        .offset = Vec2.zero(),
        .target = Vec2.zero(),
        .rotation = 0,
        .zoom = 20,
    };

    var random = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = random.random();

    var game = Gol.init(rng);

    var holding_grid = false;
    var holding_sidebar = false;

    while (!rl.windowShouldClose()) {
        if (updateScreenSize()) {
            sidebar_rect = Rect.init(
                @floatFromInt(screen_width - panel_width),
                0,
                @floatFromInt(panel_width),
                @floatFromInt(screen_height),
            );
        }

        const mouse_pos = rl.getMousePosition();
        const pointer_pos = camera.target.add(mouse_pos.scale(1 / camera.zoom));
        const scroll = rl.getMouseWheelMove();

        if (!holding_grid and (holding_sidebar or rl.checkCollisionPointRec(mouse_pos, sidebar_rect))) {
            holding_sidebar = rl.isMouseButtonDown(rl.MouseButton.left);
        }

        if (!holding_sidebar and (holding_grid or !rl.checkCollisionPointRec(mouse_pos, sidebar_rect))) {
            holding_grid = rl.isMouseButtonDown(rl.MouseButton.left);
            if (holding_grid) {
                const delta = rl.getMouseDelta().scale(-1 / camera.zoom);
                camera.target = camera.target.add(delta);
            }

            if (scroll != 0) {
                camera.zoom += scroll;
                if (camera.zoom < 0.1) {
                    camera.zoom = 0.1;
                } else if (camera.zoom > 100) {
                    camera.zoom = 100;
                }

                camera.target = pointer_pos.subtract(mouse_pos.scale(1 / camera.zoom));
            }
        }

        rl.beginDrawing();
        {
            rl.clearBackground(Color.ray_white);

            camera.begin();
            {
                for (game.getBoard(), 0..) |line, y| {
                    for (line, 0..) |tile, x| {
                        if (tile) {
                            rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, Color.red);
                        }
                    }
                }

                drawGrid(camera);
                rl.drawRectangle(-1, -1, 2, 2, Color.sky_blue.fade(0.5));
            }
            camera.end();

            _ = rg.guiPanel(sidebar_rect, "Options");
        }
        rl.endDrawing();
    }
}

fn drawGrid(camera: rl.Camera2D) void {
    const start_x: i32 = @as(i32, @intFromFloat(camera.target.x)) - 1;
    const start_y: i32 = @as(i32, @intFromFloat(camera.target.y)) - 1;
    const end_x: i32 = @as(i32, @intFromFloat(camera.target.x + @as(f32, @floatFromInt(screen_width)) / camera.zoom)) + 1;
    const end_y: i32 = @as(i32, @intFromFloat(camera.target.y + @as(f32, @floatFromInt(screen_height)) / camera.zoom)) + 1;

    var x = start_x;
    while (x < end_x) : (x += 1) {
        rl.drawLine(x, start_y, x, end_y, Color.gray.fade(0.25));
    }

    var y = start_y;
    while (y < end_y) : (y += 1) {
        rl.drawLine(start_x, y, end_x, y, Color.gray.fade(0.25));
    }
}

fn updateScreenSize() bool {
    const new_width = rl.getScreenWidth();
    const new_height = rl.getScreenHeight();

    if (new_width != screen_width or new_height != screen_height) {
        screen_width = new_width;
        screen_height = new_height;
        return true;
    }
    return false;
}
