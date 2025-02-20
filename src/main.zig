const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const Color = rl.Color;
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

    while (!rl.windowShouldClose()) {
        if (updateScreenSize()) {
            sidebar_rect = Rect.init(
                @floatFromInt(screen_width - panel_width),
                0,
                @floatFromInt(panel_width),
                @floatFromInt(screen_height),
            );
        }

        rl.beginDrawing();
        rl.clearBackground(Color.ray_white);

        _ = rg.guiPanel(sidebar_rect, "Options");

        rl.endDrawing();
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
