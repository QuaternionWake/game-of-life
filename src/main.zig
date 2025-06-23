const std = @import("std");
const math = std.math;
const List = std.ArrayList;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

const rl = @import("raylib");
const rg = @import("raygui");
const Color = rl.Color;
const Vec2 = rl.Vector2;
const Rect = rl.Rectangle;

const Gol = @import("GameOfLife.zig");
const Tile = Gol.Tile;
const StaticArrayGame = @import("games/StaticArray.zig");
const DynamicArrayGame = @import("games/DynamicArray.zig");
const HashsetGame = @import("games/Hashset.zig");
const ui = @import("ui.zig");
const pattern = @import("pattern.zig");
const GameThread = @import("GameThread.zig");

var screen_size: Vec2 = .init(800, 500);

pub const GameType = enum { @"Static Array", @"Dynamic Array", Hashset };

pub fn main() !void {
    rl.initWindow(@intFromFloat(screen_size.x), @intFromFloat(screen_size.y), "Game of Life");
    defer rl.closeWindow();
    rl.setWindowState(.{ .window_resizable = true });

    rl.setTargetFPS(60);

    rl.setExitKey(.null);

    var camera = rl.Camera2D{
        .offset = .zero(),
        .target = .zero(),
        .rotation = 0,
        .zoom = 20,
    };

    var allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = allocator.detectLeaks();
    const ally = allocator.allocator();

    var random = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = random.random();

    var static_array_game = StaticArrayGame.init(rng);
    var dynamic_array_game = try DynamicArrayGame.init(rng, ally);
    defer dynamic_array_game.deinit();
    var hashset_game = HashsetGame.init(rng, ally);
    defer hashset_game.deinit();

    var gol = static_array_game.gol();

    var clipboard = try pattern.Pattern.init("", &.{}, ally);
    defer clipboard.deinit();

    const patterns = try pattern.PatternList.init(ally);
    defer patterns.deinit();

    var debug_menu: bool = false;
    var help_menu: bool = false;

    var selection: ?Rect = null;
    var held_corner: ?Corner = null;

    var game_speed: u32 = 60;

    var game_thread: GameThread = .{};
    const thread = try Thread.spawn(.{}, GameThread.run, .{ &game_thread, gol });
    defer thread.join();
    defer game_thread.message(.{ .end_game = {} });

    while (!rl.windowShouldClose()) {
        _ = updateScreenSize();
        ui.grabElement();

        const mouse_pos = rl.getMousePosition();
        const mouse_delta = rl.getMouseDelta();
        const pointer_pos = getPointerPos(mouse_pos, camera);
        const pointer_delta = getPointerDelta(mouse_delta, camera);
        const pointer_pos_int: Tile = .{
            .x = @intFromFloat(@floor(pointer_pos.x)),
            .y = @intFromFloat(@floor(pointer_pos.y)),
        };
        const scroll = rl.getMouseWheelMove();

        if (ui.held_element == .Grid or ui.held_element == null) {
            if (!rl.isKeyDown(.left_control)) {
                // Move and zoom the camera
                // ------------------------
                if (rl.isMouseButtonDown(.left)) {
                    const delta = rl.getMouseDelta().scale(-1 / camera.zoom);
                    camera.target = camera.target.add(delta);
                }

                if (scroll != 0) {
                    camera.zoom += scroll;
                    camera.zoom = math.clamp(camera.zoom, 0.1, 100);

                    camera.target = pointer_pos.subtract(mouse_pos.scale(1 / camera.zoom));
                }

                // Modify the selection
                // --------------------
                if (rl.isMouseButtonPressed(.right)) blk: {
                    if (selection) |s| {
                        if (grabCorner(pointer_pos, s, camera)) |c| {
                            held_corner = c;
                            break :blk;
                        }
                    }
                    selection = Rect.init(pointer_pos.x, pointer_pos.y, 0, 0);
                    held_corner = .BR;
                }
                if (rl.isMouseButtonDown(.right)) blk: {
                    if (selection) |*s| {
                        if (held_corner) |c| {
                            held_corner = resizeSelection(pointer_delta, s, c);
                            break :blk;
                        }
                    }
                    selection = Rect.init(pointer_pos.x, pointer_pos.y, 0, 0);
                    held_corner = .BR;
                }
            } else blk: {
                // Edit a tile
                // -----------
                const tile = if (rl.isMouseButtonDown(.left)) true else if (rl.isMouseButtonDown(.right)) false else break :blk;
                game_thread.message(.{ .set_tile = .{ .x = pointer_pos_int.x, .y = pointer_pos_int.y, .tile = tile } });
            }
        }

        // Manipulate the held pattern
        // ---------------------------
        if (rl.isKeyPressed(.c)) {
            if (selection) |sel| {
                const bounds = getBounds(sel.x, sel.y, sel.x + sel.width, sel.y + sel.height);

                var tiles = gol.getTiles(bounds.x_start, bounds.y_start, bounds.x_end, bounds.y_end, ally);
                defer tiles.deinit();
                for (tiles.items) |*tile| {
                    tile.* = .{
                        .x = tile.x - pointer_pos_int.x,
                        .y = tile.y - pointer_pos_int.y,
                    };
                }

                clipboard.setTiles(tiles.items) catch {};
                clipboard.orientation = .{};
            }
        }
        const pat = if (ui.pattern_list.data.active) |idx| patterns.getPatternRef(idx) else &clipboard;
        if (rl.isKeyPressed(.p)) blk: {
            const tiles = pat.getTiles(ally) catch break :blk;
            game_thread.message(.{ .set_tiles = .{ .x = pointer_pos_int.x, .y = pointer_pos_int.y, .tiles = tiles } });
        }
        if (rl.isKeyPressed(.r)) {
            if (rl.isKeyDown(.left_shift) or rl.isKeyDown(.right_shift)) {
                pat.orientation.rotateCCW();
            } else {
                pat.orientation.rotateCW();
            }
        }
        if (rl.isKeyPressed(.h)) {
            pat.orientation.flipH();
        }
        if (rl.isKeyPressed(.v)) {
            pat.orientation.flipV();
        }

        if (!rl.isMouseButtonDown(.right)) {
            held_corner = null;
        }

        if (rl.isKeyPressed(.d)) {
            selection = null;
            held_corner = null;
        }

        if (rl.isKeyPressed(.escape)) {
            clipboard.setTiles(&.{}) catch {};
            ui.pattern_list.data.active = null;
        }

        if (rl.isKeyPressed(.space)) {
            if (game_thread.game_paused) {
                game_thread.message(.{ .unpause = {} });
            } else {
                game_thread.message(.{ .pause = {} });
            }
        }

        if (rl.isKeyPressed(.f1)) {
            help_menu = !help_menu;
        }

        if (rl.isKeyPressed(.f3)) {
            debug_menu = !debug_menu;
        }

        if (rl.isKeyPressed(.f11)) {
            rl.toggleFullscreen();
        }

        // Drawing
        // -------
        rl.beginDrawing();
        {
            rl.clearBackground(.ray_white);

            camera.begin();
            {
                drawTiles(camera, gol, selection, ally);

                blk: {
                    const tiles = pat.getTiles(ally) catch break :blk;
                    defer tiles.deinit();
                    drawPastePreview(camera, pointer_pos_int.x, pointer_pos_int.y, tiles.items);
                }
                if (camera.zoom > 5) {
                    drawGrid(camera);
                }
                rl.drawRectangle(-1, -1, 2, 2, Color.sky_blue.fade(0.5));

                if (selection) |s| {
                    rl.drawRectangleLinesEx(s, 2 / camera.zoom, .sky_blue);
                    if (if (held_corner) |c| c else grabCorner(pointer_pos, s, camera)) |c| blk: {
                        if (ui.held_element != .Grid and (ui.held_element != null or ui.hovered_element != .Grid)) break :blk;
                        const center = getCornerCoords(s, c);
                        const color: Color = switch (c) {
                            .TL => .maroon,
                            .TR => .green,
                            .BL => .magenta,
                            .BR => .orange,
                        };
                        const size = 6 / camera.zoom;
                        rl.drawRectangleV(center.subtractValue(size / 2), Vec2.init(size, size), color);
                    }
                }
            }
            camera.end();

            ui.drawTabButtons(ui.sidebar_tab_buttons);
            ui.drawContainer(ui.sidebar);

            switch (ui.sidebar_tab) {
                .Settings => {
                    ui.drawContainer(ui.controls);
                    if (ui.drawButton(ui.clear_button)) game_thread.message(.{ .clear = {} });
                    if (ui.drawButton(ui.randomize_button)) game_thread.message(.{ .randomize = {} });
                    if (game_thread.game_paused) {
                        if (ui.drawButton(ui.unpause_button)) game_thread.message(.{ .unpause = {} });
                        if (ui.drawButton(ui.step_button)) game_thread.message(.{ .step = {} });
                    } else {
                        if (ui.drawButton(ui.pause_button)) game_thread.message(.{ .pause = {} });
                        rg.guiSetState(@intFromEnum(rg.GuiState.state_disabled));
                        if (ui.drawButton(ui.step_button)) game_thread.message(.{ .step = {} });
                        rg.guiSetState(@intFromEnum(rg.GuiState.state_normal));
                    }

                    ui.drawContainer(ui.game_speed_box);
                    if (ui.drawSlider(ui.game_speed_slider)) {
                        game_speed = @intFromFloat(ui.game_speed_slider.data.value);
                        ui.game_speed_spinner.data.value = @intCast(game_speed);
                    }
                    if (ui.drawSpinner(ui.game_speed_spinner, true)) {
                        game_speed = @intCast(ui.game_speed_spinner.data.value);
                        ui.game_speed_slider.data.value = math.clamp(
                            @as(f32, @floatFromInt(game_speed)),
                            ui.game_speed_slider.data.min,
                            ui.game_speed_slider.data.max,
                        );
                    }
                },
                .Patterns => blk: {
                    const names_list = patterns.getNames(ally) catch break :blk;
                    defer names_list.deinit();
                    ui.drawListView(ui.pattern_list, names_list.items);
                },
                .GameTypes => {
                    switch (ui.game_type_dropdown.getSelected()) {
                        .@"Static Array" => {
                            // static array info/options
                        },
                        .@"Dynamic Array" => {
                            // dynamic array info/options
                            // xwrap
                            // ywrap
                            // xlen
                            // ylen
                            ui.drawContainer(ui.dynamic_array_options_box);
                            if (ui.drawSpinner(ui.dynamic_array_width_spinner, false)) {
                                dynamic_array_game.setXLen(@intCast(ui.dynamic_array_width_spinner.data.value));
                            }
                            if (ui.drawSpinner(ui.dynamic_array_height_spinner, false)) {
                                dynamic_array_game.setYLen(@intCast(ui.dynamic_array_height_spinner.data.value));
                            }
                            if (ui.drawDropdown(ui.dynamic_array_ywrap_dropdown)) {
                                dynamic_array_game.setYWrap(ui.dynamic_array_ywrap_dropdown.getSelected());
                            }
                            if (ui.drawDropdown(ui.dynamic_array_xwrap_dropdown)) {
                                dynamic_array_game.setXWrap(ui.dynamic_array_xwrap_dropdown.getSelected());
                            }
                        },
                        .Hashset => {
                            // hashset info/options
                        },
                    }

                    if (ui.drawDropdown(ui.game_type_dropdown)) {
                        gol = switch (ui.game_type_dropdown.getSelected()) {
                            .@"Static Array" => static_array_game.gol(),
                            .@"Dynamic Array" => dynamic_array_game.gol(),
                            .Hashset => hashset_game.gol(),
                        };
                        game_thread.message(.{ .change_game = gol });
                    }
                },
            }

            const new_target_speed = std.time.ns_per_s / @as(u64, @intCast(@max(game_speed, 1)));
            if (new_target_speed != game_thread.time_target_ns) {
                game_thread.message(.{ .set_game_speed = new_target_speed });
            }

            if (debug_menu) {
                const avg_time_ns = blk: {
                    var sum: u64 = 0;
                    for (game_thread.times) |time| {
                        sum += time;
                    }
                    break :blk @as(f64, @floatFromInt(sum)) / game_thread.times.len;
                };
                const avg_time_arg, const avg_time_fmt = if (avg_time_ns < std.time.ns_per_ms) blk: {
                    break :blk .{ avg_time_ns / std.time.ns_per_us, "Avg gen time: %.2fus" };
                } else if (avg_time_ns < std.time.ns_per_s) blk: {
                    break :blk .{ avg_time_ns / std.time.ns_per_ms, "Avg gen time: %.2fms" };
                } else blk: {
                    break :blk .{ avg_time_ns / std.time.ns_per_s, "Avg gen time: %.2fs" };
                };
                // TODO
                const gens_per_s = 1 / (avg_time_ns / std.time.ns_per_s);
                rl.drawText(rl.textFormat(avg_time_fmt, .{avg_time_arg}), 10, 10, 17, .dark_gray);
                rl.drawText(rl.textFormat("Gens per sec (max/target): %.0f/%d", .{ gens_per_s, game_speed }), 10, 30, 17, .dark_gray);
                rl.drawText(rl.textFormat("Generation: %d", .{game_thread.generation}), 10, 50, 17, .dark_gray);
                rl.drawText(rl.textFormat("Mouse pos: %.0f, %.0f", .{ mouse_pos.x, mouse_pos.y }), 10, 70, 17, .dark_gray);
                rl.drawText(rl.textFormat("Pointer pos: %.2f, %.2f", .{ pointer_pos.x, pointer_pos.y }), 10, 90, 17, .dark_gray);
                rl.drawText(rl.textFormat("Camera pos: %.2f, %.2f, Zoom: %.4f", .{ camera.target.x, camera.target.y, camera.zoom }), 10, 110, 17, .dark_gray);
            }

            if (help_menu) {
                rl.drawText("F1 - Help    F3 - Debug menu    F11 - Fullscreen", 10, @as(i32, @intFromFloat(screen_size.y)) - 70 - 17, 17, .dark_gray);
                rl.drawText("Mouse L/R: Drag/Select    CTRL + Mouse - Edit board", 10, @as(i32, @intFromFloat(screen_size.y)) - 50 - 17, 17, .dark_gray);
                rl.drawText("C - Copy    P - Paste    H/V - Flip horizontally/vertically    R - Rotate [SHIFT to invert]", 10, @as(i32, @intFromFloat(screen_size.y)) - 30 - 17, 17, .dark_gray);
                rl.drawText("D - Deselect    ESC - Clear clipboard & pattern    SPACE - Pause", 10, @as(i32, @intFromFloat(screen_size.y)) - 10 - 17, 17, .dark_gray);
            }
        }
        rl.endDrawing();
    }
}

fn getPointerPos(mouse_pos: Vec2, camera: rl.Camera2D) Vec2 {
    return camera.target.add(mouse_pos.scale(1 / camera.zoom));
}

fn getPointerDelta(mouse_delta: Vec2, camera: rl.Camera2D) Vec2 {
    return mouse_delta.scale(1 / camera.zoom);
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

fn grabCorner(pointer_pos: Vec2, selection: Rect, camera: rl.Camera2D) ?Corner {
    const corner_tl = Vec2.init(selection.x, selection.y);
    const corner_tr = Vec2.init(selection.x + selection.width, selection.y);
    const corner_bl = Vec2.init(selection.x, selection.y + selection.height);
    const corner_br = Vec2.init(selection.x + selection.width, selection.y + selection.height);
    const dist_tl = pointer_pos.distanceSqr(corner_tl);
    const dist_tr = pointer_pos.distanceSqr(corner_tr);
    const dist_bl = pointer_pos.distanceSqr(corner_bl);
    const dist_br = pointer_pos.distanceSqr(corner_br);
    const dists: [4]f32 = .{ dist_tl, dist_tr, dist_bl, dist_br };
    const minidx = std.mem.indexOfMin(f32, &dists);
    if (dists[minidx] < 100 / math.pow(f32, camera.zoom, 2)) {
        return switch (minidx) {
            0 => .TL,
            1 => .TR,
            2 => .BL,
            3 => .BR,
            else => null,
        };
    } else return null;
}

fn resizeSelection(pointer_delta: Vec2, selection: *Rect, held_corner: Corner) Corner {
    const pos = Vec2.init(selection.x, selection.y);
    const size = Vec2.init(selection.width, selection.height);
    const new_pos_x = switch (held_corner) {
        .TL, .BL => pos.x + pointer_delta.x,
        .TR, .BR => pos.x,
    };
    const new_pos_y = switch (held_corner) {
        .TL, .TR => pos.y + pointer_delta.y,
        .BL, .BR => pos.y,
    };
    const new_size_x = switch (held_corner) {
        .TL, .BL => size.x - pointer_delta.x,
        .TR, .BR => size.x + pointer_delta.x,
    };
    const new_size_y = switch (held_corner) {
        .TL, .TR => size.y - pointer_delta.y,
        .BL, .BR => size.y + pointer_delta.y,
    };
    const rect = Rect.init(new_pos_x, new_pos_y, new_size_x, new_size_y);

    selection.* = normalizeRect(rect);
    var retval = held_corner;
    if (rect.width < 0) retval = retval.hFlip();
    if (rect.height < 0) retval = retval.vFlip();
    return retval;
}

const Corner = enum {
    TL,
    TR,
    BL,
    BR,

    pub fn vFlip(self: Corner) Corner {
        return switch (self) {
            .TR => .BR,
            .TL => .BL,
            .BR => .TR,
            .BL => .TL,
        };
    }

    pub fn hFlip(self: Corner) Corner {
        return switch (self) {
            .TR => .TL,
            .TL => .TR,
            .BR => .BL,
            .BL => .BR,
        };
    }
};

fn getCornerCoords(rect: Rect, corner: Corner) Vec2 {
    return switch (corner) {
        .TL => Vec2.init(rect.x, rect.y),
        .TR => Vec2.init(rect.x + rect.width, rect.y),
        .BL => Vec2.init(rect.x, rect.y + rect.height),
        .BR => Vec2.init(rect.x + rect.width, rect.y + rect.height),
    };
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
    const bounds = getBounds(camera.target.x, camera.target.y, other_corner.x, other_corner.y);

    const tiles = gol.getTiles(bounds.x_start, bounds.y_start, bounds.x_end, bounds.y_end, ally);
    defer tiles.deinit();

    if (selection) |sel| {
        const sel_bounds = getBounds(sel.x, sel.y, sel.x + sel.width, sel.y + sel.height);

        for (tiles.items) |tile| {
            if (sel_bounds.contains(tile)) {
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

fn drawPastePreview(camera: rl.Camera2D, x: isize, y: isize, tiles: []Tile) void {
    const other_corner = otherScreenCorner(camera);
    const bounds = getBounds(camera.target.x, camera.target.y, other_corner.x, other_corner.y);

    for (tiles) |orig_tile| {
        const tile: Tile = .{ .x = orig_tile.x + x, .y = orig_tile.y + y };
        if (bounds.contains(tile)) {
            rl.drawRectangle(@intCast(tile.x), @intCast(tile.y), 1, 1, Color.magenta.fade(0.5));
        }
    }
}

const Bounds = struct {
    x_start: isize,
    y_start: isize,
    x_end: isize,
    y_end: isize,

    pub fn contains(self: Bounds, tile: Tile) bool {
        return self.x_start <= tile.x and tile.x < self.x_end and self.y_start <= tile.y and tile.y < self.y_end;
    }
};

fn getBounds(x_start: f32, y_start: f32, x_end: f32, y_end: f32) Bounds {
    return .{
        .x_start = math.lossyCast(isize, @floor(x_start)),
        .y_start = math.lossyCast(isize, @floor(y_start)),
        .x_end = math.lossyCast(isize, @ceil(x_end)),
        .y_end = math.lossyCast(isize, @ceil(y_end)),
    };
}

fn otherScreenCorner(camera: rl.Camera2D) Vec2 {
    return camera.target.add(screen_size.scale(1 / camera.zoom));
}

fn updateScreenSize() bool {
    const new_size: Vec2 = .init(
        @floatFromInt(rl.getRenderWidth()),
        @floatFromInt(rl.getRenderHeight()),
    );

    // For some reason render size and screen size get desynced when exiting
    // fullscreen which breaks rendering so we must do this to keep them synced
    rl.setWindowSize(
        @intFromFloat(new_size.x),
        @intFromFloat(new_size.y),
    );

    if (new_size.equals(screen_size) == 0) {
        screen_size = new_size;
        return true;
    }
    return false;
}
