const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const Gol = @import("game-of-life.zig");
const ui = @import("ui.zig");

const Color = rl.Color;
const Vec2 = rl.Vector2;
const Rect = rl.Rectangle;

var screen_width: i32 = 800;
var screen_height: i32 = 500;

pub fn main() !void {
    rl.initWindow(screen_width, screen_height, "Game of Life");
    defer rl.closeWindow();
    rl.setWindowState(.{ .window_resizable = true });

    rl.setTargetFPS(60);

    var camera = rl.Camera2D{
        .offset = .zero(),
        .target = .zero(),
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

    var selection: ?Rect = null;

    ui.updateSidebar(screen_width, screen_height);

    const EditMode = enum { Move, Edit, Select };
    var edit_mode: EditMode = .Move;

    while (!rl.windowShouldClose()) {
        if (updateScreenSize()) {
            ui.updateSidebar(screen_width, screen_height);
        }

        const mouse_pos = rl.getMousePosition();
        const pointer_pos = getPointerPos(mouse_pos, camera);
        const scroll = rl.getMouseWheelMove();

        if (rl.isKeyPressed(.p)) {
            game_paused = !game_paused;
        }

        if (!game_paused) {
            game.next();
        }

        if (edit_mode == .Move or rl.isKeyDown(.left_control)) {
            // Move and zoom the camera
            // ------------------------
            if (!holding_grid and (holding_sidebar or rl.checkCollisionPointRec(mouse_pos, ui.sidebar.getRect()))) {
                holding_sidebar = rl.isMouseButtonDown(.left);
            }

            if (!holding_sidebar and (holding_grid or !rl.checkCollisionPointRec(mouse_pos, ui.sidebar.getRect()))) {
                holding_grid = rl.isMouseButtonDown(.left);
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
        } else if (edit_mode == .Edit) blk: {
            // Edit a tile
            // -----------
            const new_tile_state = if (rl.isMouseButtonDown(.left)) true else if (rl.isMouseButtonDown(.right)) false else break :blk;

            const pointer_tile = .{
                .x = @as(i32, @intFromFloat(@floor(pointer_pos.x))),
                .y = @as(i32, @intFromFloat(@floor(pointer_pos.y))),
            };
            if (pointer_tile.x >= 0 and pointer_tile.x < Gol.x_len and
                pointer_tile.y >= 0 and pointer_tile.y < Gol.y_len)
            {
                game.getBoard()[@intCast(pointer_tile.y)][@intCast(pointer_tile.x)] = new_tile_state;
            }
        } else if (edit_mode == .Select) {
            // Modify the selection
            // --------------------
            if (rl.isMouseButtonDown(.left)) {
                if (selection) |*s| {
                    const pos = Vec2.init(s.x, s.y);
                    const size = pointer_pos.subtract(pos);
                    s.width = size.x;
                    s.height = size.y;
                } else {
                    selection = Rect.init(pointer_pos.x, pointer_pos.y, 0, 0);
                }
            } else {
                selection = null;
            }
        }

        rl.beginDrawing();
        {
            rl.clearBackground(.ray_white);

            camera.begin();
            {
                drawTiles(camera, game.getBoard(), selection);

                if (camera.zoom > 5) {
                    drawGrid(camera);
                }
                rl.drawRectangle(-1, -1, 2, 2, Color.sky_blue.fade(0.5));

                if (selection) |s| {
                    rl.drawRectangleLinesEx(normalizeRect(s), 2 / camera.zoom, .sky_blue);
                }
            }
            camera.end();

            ui.drawContainer(ui.sidebar);
            ui.drawContainer(ui.controls);

            ui.drawButton(ui.clear_button, .{ .game = &game });
            ui.drawButton(ui.randomize_button, .{ .game = &game, .rng = rng });
            if (game_paused) {
                ui.drawButton(ui.unpause_button, .{ .paused = &game_paused });
            } else {
                ui.drawButton(ui.pause_button, .{ .paused = &game_paused });
            }
            ui.drawButton(ui.step_button, .{ .game = &game });

            edit_mode = ui.drawRadioButtons(ui.edit_mode_radio, edit_mode);
        }
        rl.endDrawing();
    }
}

fn getPointerPos(mouse_pos: Vec2, camera: rl.Camera2D) Vec2 {
    return camera.target.add(mouse_pos.scale(1 / camera.zoom));
}

fn normalizeRect(rect: Rect) Rect {
    var res = rect;
    if (rect.width < 0) {
        res.x += rect.width;
        res.width = -rect.width;
    }
    if (rect.height < 0) {
        res.y += rect.height;
        res.height = -rect.height;
    }
    return res;
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

fn drawTiles(camera: rl.Camera2D, board: *Gol.Board, selection: ?Rect) void {
    const start_x: usize = @intCast(@max(@as(i32, @intFromFloat(camera.target.x)) - 1, 0));
    const start_y: usize = @intCast(@max(@as(i32, @intFromFloat(camera.target.y)) - 1, 0));
    const end_x: usize = @intCast(std.math.clamp(@as(i32, @intFromFloat(camera.target.x + @as(f32, @floatFromInt(screen_width)) / camera.zoom)) + 1, 0, Gol.x_len));
    const end_y: usize = @intCast(std.math.clamp(@as(i32, @intFromFloat(camera.target.y + @as(f32, @floatFromInt(screen_height)) / camera.zoom)) + 1, 0, Gol.y_len));

    if (selection) |select| {
        const sel = normalizeRect(select);
        const sel_start_x: usize = @intFromFloat(@floor(@max(camera.target.x - 1, sel.x, 0)));
        const sel_start_y: usize = @intFromFloat(@floor(@max(camera.target.y - 1, sel.y, 0)));
        const sel_end_x: usize = @intFromFloat(std.math.clamp(sel.x + sel.width + 1, 0, Gol.x_len));
        const sel_end_y: usize = @intFromFloat(std.math.clamp(sel.y + sel.height + 1, 0, Gol.y_len));

        var x = start_x;
        while (x < end_x) : (x += 1) {
            var y = start_y;
            while (y < end_y) : (y += 1) {
                if (board[y][x]) {
                    if (sel_start_x <= x and x < sel_end_x and sel_start_y <= y and y < sel_end_y) {
                        rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, .blue);
                    } else {
                        rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, .red);
                    }
                }
            }
        }
    } else {
        var x = start_x;
        while (x < end_x) : (x += 1) {
            var y = start_y;
            while (y < end_y) : (y += 1) {
                if (board[y][x]) {
                    rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, .red);
                }
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
