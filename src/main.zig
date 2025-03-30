const std = @import("std");
const math = std.math;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

const rl = @import("raylib");
const rg = @import("raygui");

const Gol = @import("game-of-life.zig");
const BasicGame = @import("games/basic.zig");
const ui = @import("ui.zig");
const game_thread = @import("game-thread.zig");

const Color = rl.Color;
const Vec2 = rl.Vector2;
const Rect = rl.Rectangle;

var screen_size: Vec2 = .init(800, 500);

pub fn main() !void {
    rl.initWindow(@intFromFloat(screen_size.x), @intFromFloat(screen_size.y), "Game of Life");
    defer rl.closeWindow();
    rl.setWindowState(.{ .window_resizable = true });

    rl.setTargetFPS(60);

    var camera = rl.Camera2D{
        .offset = .zero(),
        .target = .zero(),
        .rotation = 0,
        .zoom = 20,
    };

    var allocator = std.heap.DebugAllocator(.{}).init;
    const ally = allocator.allocator();

    var random = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = random.random();

    var game = BasicGame.init(rng);
    const gol = game.gol();

    var holding_grid = false;
    var holding_sidebar = false;
    var editing_game_speed = false;

    var selection: ?Rect = null;

    ui.updateSidebar(screen_size);

    var game_speed: i32 = 60;

    const EditMode = enum { Move, Edit, Select };
    var edit_mode: EditMode = .Move;

    const thread = try Thread.spawn(.{}, game_thread.run, .{gol});
    defer thread.join();
    defer game_thread.should_end = true;

    while (!rl.windowShouldClose()) {
        if (updateScreenSize()) {
            ui.updateSidebar(screen_size);
        }

        const mouse_pos = rl.getMousePosition();
        const pointer_pos = getPointerPos(mouse_pos, camera);
        const scroll = rl.getMouseWheelMove();

        if (rl.isKeyPressed(.p)) {
            game_thread.game_paused = !game_thread.game_paused;
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
                    camera.zoom = math.clamp(camera.zoom, 0.1, 100);

                    camera.target = pointer_pos.subtract(mouse_pos.scale(1 / camera.zoom));
                }
            }
        } else if (edit_mode == .Edit) blk: {
            // Edit a tile
            // -----------
            const tile = if (rl.isMouseButtonDown(.left)) true else if (rl.isMouseButtonDown(.right)) false else break :blk;
            gol.setTile(@intFromFloat(@floor(pointer_pos.x)), @intFromFloat(@floor(pointer_pos.y)), tile);
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
                drawTiles(camera, gol, selection, ally);

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

            ui.drawButton(ui.clear_button, .{ .clear = &game_thread.clear });
            ui.drawButton(ui.randomize_button, .{ .randomize = &game_thread.randomize });
            if (game_thread.game_paused) {
                ui.drawButton(ui.unpause_button, .{ .paused = &game_thread.game_paused });
                ui.drawButton(ui.step_button, .{ .step = &game_thread.step });
            } else {
                ui.drawButton(ui.pause_button, .{ .paused = &game_thread.game_paused });
                rg.guiSetState(@intFromEnum(rg.GuiState.state_disabled));
                ui.drawButton(ui.step_button, .{ .step = &game_thread.step });
                rg.guiSetState(@intFromEnum(rg.GuiState.state_normal));
            }

            ui.drawContainer(ui.game_speed_box);
            var game_speed_f: f32 = @floatFromInt(@max(game_speed, 1)); // @max is needed here so the spinner later on can be zero
            if (ui.drawSlider(ui.game_speed_slider, &game_speed_f, 1, 240)) {
                game_speed = @intFromFloat(game_speed_f);
            }
            if (ui.drawSpinner(ui.game_speed_spinner, &game_speed, 0, 240, editing_game_speed)) {
                editing_game_speed = !editing_game_speed;
            }

            game_thread.time_target_ns = std.time.ns_per_s / @as(u64, @intCast(@max(game_speed, 1)));

            // TODO: make average gen time calculation not suck
            const avg_time = blk: {
                var sum: u64 = 0;
                for (game_thread.times) |time| {
                    sum += time;
                }
                break :blk @as(f64, @floatFromInt(sum)) / std.time.ns_per_us / game_thread.times.len;
            };
            rl.drawText(rl.textFormat("Avg gen time: %.2fus", .{avg_time}), 90, 20, 17, .dark_gray);

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
    const other_corner = otherScreenCorner(camera);
    const start_x: i32 = @intFromFloat(@floor(camera.target.x));
    const start_y: i32 = @intFromFloat(@floor(camera.target.y));
    const end_x: i32 = @intFromFloat(@ceil(other_corner.x));
    const end_y: i32 = @intFromFloat(@ceil(other_corner.y));

    var x = start_x;
    while (x < end_x) : (x += 1) {
        rl.drawLine(x, start_y, x, end_y, Color.gray.fade(0.25));
    }

    var y = start_y;
    while (y < end_y) : (y += 1) {
        rl.drawLine(start_x, y, end_x, y, Color.gray.fade(0.25));
    }
}

fn drawTiles(camera: rl.Camera2D, gol: Gol, selection: ?Rect, ally: Allocator) void {
    const other_corner = otherScreenCorner(camera);

    const start_x = math.lossyCast(isize, @floor(camera.target.x));
    const start_y = math.lossyCast(isize, @floor(camera.target.y));
    const end_x = math.lossyCast(isize, @ceil(other_corner.x));
    const end_y = math.lossyCast(isize, @ceil(other_corner.y));

    const tiles = gol.getTiles(start_x, start_y, end_x, end_y, ally);
    defer tiles.deinit();

    if (selection) |select| {
        const sel = normalizeRect(select);
        const sel_start_x = math.lossyCast(isize, @floor(@max(camera.target.x, sel.x)));
        const sel_start_y = math.lossyCast(isize, @floor(@max(camera.target.y, sel.y)));
        const sel_end_x = math.lossyCast(isize, @ceil(@min(sel.x + sel.width, other_corner.x)));
        const sel_end_y = math.lossyCast(isize, @ceil(@min(sel.y + sel.height, other_corner.y)));

        for (tiles.items) |tile| {
            if (sel_start_x <= tile.x and tile.x < sel_end_x and sel_start_y <= tile.y and tile.y < sel_end_y) {
                rl.drawRectangle(@intCast(tile.x), @intCast(tile.y), 1, 1, .blue);
            } else {
                rl.drawRectangle(@intCast(tile.x), @intCast(tile.y), 1, 1, .red);
            }
        }
    } else {
        for (tiles.items) |tile| {
            rl.drawRectangle(@intCast(tile.x), @intCast(tile.y), 1, 1, .red);
        }
    }
}

fn otherScreenCorner(camera: rl.Camera2D) Vec2 {
    return camera.target.add(screen_size.scale(1 / camera.zoom));
}

fn updateScreenSize() bool {
    const new_size: Vec2 = .init(
        @floatFromInt(rl.getScreenWidth()),
        @floatFromInt(rl.getScreenHeight()),
    );

    if (new_size.equals(screen_size) == 0) {
        screen_size = new_size;
        return true;
    }
    return false;
}
