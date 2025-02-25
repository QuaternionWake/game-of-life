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

    var control_rect = Rect.init(
        sidebar_rect.x + 20,
        sidebar_rect.y + 40,
        sidebar_rect.width - 40,
        140,
    );

    var pause_button_rect = Rect.init(
        control_rect.x + 20,
        control_rect.y + 20,
        control_rect.width - 40,
        40,
    );

    var step_button_rect = pause_button_rect;
    step_button_rect.y += 60;

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
    var game_paused = false;

    while (!rl.windowShouldClose()) {
        if (updateScreenSize()) {
            sidebar_rect.x = @floatFromInt(screen_width - panel_width);
            sidebar_rect.height = @floatFromInt(screen_height);
            control_rect.x = sidebar_rect.x + 20;
            pause_button_rect.x = control_rect.x + 20;
            step_button_rect.x = control_rect.x + 20;
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

        if (rl.isKeyPressed(rl.KeyboardKey.p)) {
            game_paused = !game_paused;
        }

        if (!game_paused) {
            game.next();
        }

        if (rl.isMouseButtonDown(rl.MouseButton.right)) {
            const pointer_tile_x: i32 = @intFromFloat(@floor(pointer_pos.x));
            const pointer_tile_y: i32 = @intFromFloat(@floor(pointer_pos.y));
            if (pointer_tile_x >= 0 and pointer_tile_x < Gol.x_len and
                pointer_tile_y >= 0 and pointer_tile_y < Gol.y_len)
            {
                game.getBoard()[@intCast(pointer_tile_y)][@intCast(pointer_tile_x)] = true;
            }
        }

        rl.beginDrawing();
        {
            rl.clearBackground(Color.ray_white);

            camera.begin();
            {
                drawTiles(camera, game.getBoard());

                if (camera.zoom > 5) {
                    drawGrid(camera);
                }
                rl.drawRectangle(-1, -1, 2, 2, Color.sky_blue.fade(0.5));
            }
            camera.end();

            _ = rg.guiPanel(sidebar_rect, "Options");
            _ = rg.guiGroupBox(control_rect, "Game controls");
            if (rg.guiButton(pause_button_rect, if (game_paused) blk: {
                break :blk "Unpause";
            } else blk: {
                break :blk "Pause";
            }) != 0) {
                game_paused = !game_paused;
            }
            if (game_paused) {
                if (rg.guiButton(step_button_rect, "Step") != 0) {
                    game.next();
                }
            }
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

fn drawTiles(camera: rl.Camera2D, board: *Gol.Board) void {
    const start_x: usize = @intCast(@max(@as(i32, @intFromFloat(camera.target.x)) - 1, 0));
    const start_y: usize = @intCast(@max(@as(i32, @intFromFloat(camera.target.y)) - 1, 0));
    const end_x: usize = @intCast(std.math.clamp(@as(i32, @intFromFloat(camera.target.x + @as(f32, @floatFromInt(screen_width)) / camera.zoom)) + 1, 0, Gol.x_len));
    const end_y: usize = @intCast(std.math.clamp(@as(i32, @intFromFloat(camera.target.y + @as(f32, @floatFromInt(screen_height)) / camera.zoom)) + 1, 0, Gol.y_len));

    var x = start_x;
    while (x < end_x) : (x += 1) {
        var y = start_y;
        while (y < end_y) : (y += 1) {
            if (board[y][x]) {
                rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, Color.red);
            }
        }
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
