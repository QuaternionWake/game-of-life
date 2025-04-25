const std = @import("std");
const math = std.math;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

const rl = @import("raylib");
const rg = @import("raygui");

const Gol = @import("game-of-life.zig");
const Tile = Gol.Tile;
const TileList = Gol.TileList;
const BasicGame = @import("games/basic.zig");
const HashsetGame = @import("games/hashset.zig");
const ui = @import("ui.zig");
const pattern = @import("pattern.zig");
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
    defer _ = allocator.detectLeaks();
    const ally = allocator.allocator();

    var random = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = random.random();

    // var game = BasicGame.init(rng);
    var game = HashsetGame.init(rng, ally);
    defer game.deinit();
    const gol = game.gol();

    var clipboard = TileList.init(ally);

    const patterns = try pattern.PatternList.init(ally);
    defer patterns.deinit();

    var pat_list_scroll: i32 = 0;
    var pat_list_active: ?usize = null;
    var pat_list_focused: ?usize = null;

    var holding_grid = false;
    var holding_sidebar = false;
    var editing_game_speed = false;

    var selection: ?Rect = null;
    var held_corner: ?Corner = null;

    ui.updateSidebar(screen_size);

    var game_speed: i32 = 60;

    const EditMode = enum { Move, Edit, Select };
    var edit_mode: EditMode = .Move;

    const SidebarTabs = enum { Settings, Patterns };
    var sidebar_tab: SidebarTabs = .Settings;

    const thread = try Thread.spawn(.{}, game_thread.run, .{gol});
    defer thread.join();
    defer game_thread.should_end = true;

    while (!rl.windowShouldClose()) {
        if (updateScreenSize()) {
            ui.updateSidebar(screen_size);
        }

        const mouse_pos = rl.getMousePosition();
        const mouse_delta = rl.getMouseDelta();
        const pointer_pos = getPointerPos(mouse_pos, camera);
        const pointer_delta = getPointerDelta(mouse_delta, camera);
        const scroll = rl.getMouseWheelMove();

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
            if (rl.isMouseButtonPressed(.left)) blk: {
                if (selection) |s| {
                    if (grabCorner(pointer_pos, s, camera)) |c| {
                        held_corner = c;
                        break :blk;
                    }
                }
                selection = Rect.init(pointer_pos.x, pointer_pos.y, 0, 0);
                held_corner = .BR;
            }
            if (rl.isMouseButtonDown(.left)) blk: {
                if (selection) |*s| {
                    if (held_corner) |c| {
                        held_corner = resizeSelection(pointer_delta, s, c);
                        break :blk;
                    }
                }
                selection = Rect.init(pointer_pos.x, pointer_pos.y, 0, 0);
                held_corner = .BR;
            } else if (rl.isMouseButtonDown(.right)) {
                if (selection) |*s| {
                    s.x += pointer_delta.x;
                    s.y += pointer_delta.y;
                }
            }
            if (!rl.isMouseButtonDown(.left)) {
                held_corner = null;
            }
            if (rl.isKeyPressed(.c)) {
                if (selection) |sel| {
                    const s = sel;
                    const start_x = math.lossyCast(isize, @floor(s.x));
                    const start_y = math.lossyCast(isize, @floor(s.y));
                    const end_x = math.lossyCast(isize, @ceil(s.x + s.width));
                    const end_y = math.lossyCast(isize, @ceil(s.y + s.height));

                    clipboard.deinit();
                    clipboard = gol.getTiles(start_x, start_y, end_x, end_y, ally);
                    for (clipboard.items) |*tile| {
                        tile.* = .{
                            .x = tile.x - @as(isize, @intFromFloat(pointer_pos.x)),
                            .y = tile.y - @as(isize, @intFromFloat(pointer_pos.y)),
                        };
                    }
                }
            }
            if (rl.isKeyPressed(.p)) {
                // TODO: make pasting not limited to select mode
                const x: isize = @intFromFloat(pointer_pos.x);
                const y: isize = @intFromFloat(pointer_pos.y);
                if (pat_list_active) |idx| {
                    gol.setTiles(x, y, patterns.getTiles(idx));
                } else {
                    gol.setTiles(x, y, clipboard.items);
                }
            }
            if (rl.isKeyPressed(.d)) {
                selection = null;
                held_corner = null;
            }
        }
        if (edit_mode != .Select) {
            selection = null;
            held_corner = null;
        }

        rl.beginDrawing();
        {
            rl.clearBackground(.ray_white);

            camera.begin();
            {
                drawTiles(camera, gol, selection, ally);

                if (edit_mode == .Select) {
                    const x: isize = @intFromFloat(pointer_pos.x);
                    const y: isize = @intFromFloat(pointer_pos.y);
                    if (pat_list_active) |idx| {
                        drawPastePreview(camera, x, y, patterns.getTiles(idx));
                    } else {
                        drawPastePreview(camera, x, y, clipboard.items);
                    }
                }
                if (camera.zoom > 5) {
                    drawGrid(camera);
                }
                rl.drawRectangle(-1, -1, 2, 2, Color.sky_blue.fade(0.5));

                if (selection) |s| {
                    rl.drawRectangleLinesEx(s, 2 / camera.zoom, .sky_blue);
                    if (if (held_corner) |c| c else grabCorner(pointer_pos, s, camera)) |c| {
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

            sidebar_tab = ui.drawTabButtons(ui.sidebar_tab_buttons, sidebar_tab);
            ui.drawContainer(ui.sidebar);
            switch (sidebar_tab) {
                .Settings => {
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
                },
                .Patterns => blk: {
                    const names_list = patterns.getNames(ally) catch break :blk;
                    defer names_list.deinit();
                    ui.drawListView(ui.pattern_list, names_list.items, &pat_list_scroll, &pat_list_active, &pat_list_focused);
                },
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

    const start_x = math.lossyCast(isize, @floor(camera.target.x));
    const start_y = math.lossyCast(isize, @floor(camera.target.y));
    const end_x = math.lossyCast(isize, @ceil(other_corner.x));
    const end_y = math.lossyCast(isize, @ceil(other_corner.y));

    const tiles = gol.getTiles(start_x, start_y, end_x, end_y, ally);
    defer tiles.deinit();

    if (selection) |select| {
        const sel = select;
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

fn drawPastePreview(camera: rl.Camera2D, x: isize, y: isize, tiles: []Tile) void {
    const other_corner = otherScreenCorner(camera);

    const start_x = math.lossyCast(isize, @floor(camera.target.x));
    const start_y = math.lossyCast(isize, @floor(camera.target.y));
    const end_x = math.lossyCast(isize, @ceil(other_corner.x));
    const end_y = math.lossyCast(isize, @ceil(other_corner.y));

    for (tiles) |orig_tile| {
        const tile = .{ .x = orig_tile.x + x, .y = orig_tile.y + y };
        if (start_x <= tile.x and tile.x < end_x and start_y <= tile.y and tile.y < end_y) {
            rl.drawRectangle(@intCast(tile.x), @intCast(tile.y), 1, 1, Color.magenta.fade(0.5));
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
