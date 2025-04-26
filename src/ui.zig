const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");
const Vec2 = rl.Vector2;
const Rect = rl.Rectangle;

pub const sidebar_width = 250;

pub fn drawButton(b: Button) bool {
    const rect = rectFromVecs(b.getPos(), b.size);

    return rg.guiButton(rect, b.text) != 0;
}

pub fn drawContainer(c: Container) void {
    const rect = rectFromVecs(c.getPos(), c.size);

    switch (c.type) {
        .Panel => {
            _ = rg.guiPanel(rect, c.title);
        },
        .GroupBox => {
            _ = rg.guiGroupBox(rect, c.title);
        },
    }
}

pub fn drawRadioButtons(rb: RadioButtons, radio_enum: anytype) @TypeOf(radio_enum) {
    if (@typeInfo(@TypeOf(radio_enum)) != .@"enum") {
        @compileError("Expected enum type, found '" ++ @typeName(radio_enum) ++ "'");
    }

    var rect = rectFromVecs(rb.getPos(), rb.radio_size);

    const fields = std.meta.fields(@TypeOf(radio_enum));

    var retval = radio_enum;
    inline for (fields) |field| {
        const b1 = field.value == @intFromEnum(radio_enum);
        var b2 = b1;
        _ = rg.guiCheckBox(rect, field.name, &b2);
        if (b2 != b1) {
            retval = @enumFromInt(field.value);
        }

        rect.x += rb.offset.x;
        rect.y += rb.offset.y;
    }
    return retval;
}

pub fn drawTabButtons(tb: TabButtons, tab_enum: anytype) struct { @TypeOf(tab_enum), bool } {
    if (@typeInfo(@TypeOf(tab_enum)) != .@"enum") {
        @compileError("Expected enum type, found '" ++ @typeName(tab_enum) ++ "'");
    }

    var rect = rectFromVecs(tb.getPos(), tb.size);

    const fields = std.meta.fields(@TypeOf(tab_enum));

    var retval = tab_enum;
    var hovering = false;
    inline for (fields) |field| {
        if (rg.guiButton(rect, field.name) != 0) {
            retval = @enumFromInt(field.value);
        }
        if (rl.checkCollisionPointRec(rl.getMousePosition(), rect)) {
            hovering = true;
        }

        rect.x += tb.offset.x;
        rect.y += tb.offset.y;
    }
    return .{ retval, hovering };
}

pub fn drawListView(list: List, items: [][*:0]const u8, scroll: *i32, active: *?usize, focused: *?usize) void {
    const rect = rectFromVecs(list.getPos(), list.size);
    var active_inner: i32 = if (active.*) |a| @intCast(a) else -1;
    var focused_inner: i32 = if (focused.*) |f| @intCast(f) else -1;

    _ = rg.guiListViewEx(rect, items, scroll, &active_inner, &focused_inner);

    active.* = if (active_inner != -1) @intCast(active_inner) else null;
    focused.* = if (focused_inner != -1) @intCast(focused_inner) else null;
}

pub fn drawSlider(s: Slider, val: *f32, min: f32, max: f32) bool {
    const rect = rectFromVecs(s.getPos(), s.size);

    return rg.guiSlider(rect, s.text_left, s.text_right, val, min, max) != 0;
}

pub fn drawSpinner(sb: Spinner, val: *i32, min: i32, max: i32, edit_mode: bool) bool {
    const rect = rectFromVecs(sb.getPos(), sb.size);

    return rg.guiSpinner(rect, sb.text, val, min, max, edit_mode) != 0;
}

fn rectFromVecs(pos: Vec2, size: Vec2) Rect {
    return .init(pos.x, pos.y, size.x, size.y);
}

pub fn updateSidebar(screen_size: Vec2) void {
    sidebar.pos.x = screen_size.x - sidebar_width;
    sidebar.size.y = screen_size.y;
}

const Container = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    title: [:0]const u8,
    type: enum { Panel, GroupBox },

    pub fn getRect(self: Container) Rect {
        return Rect.init(self.pos.x, self.pos.y, self.size.x, self.size.y);
    }

    pub fn getPos(self: Container) Vec2 {
        if (self.container) |c| {
            return c.getPos().add(self.pos);
        } else {
            return self.pos;
        }
    }
};

const Button = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    text: [:0]const u8,

    pub fn getPos(self: Button) Vec2 {
        if (self.container) |c| {
            return c.getPos().add(self.pos);
        } else {
            return self.pos;
        }
    }
};

const List = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,

    pub fn getPos(self: List) Vec2 {
        if (self.container) |c| {
            return c.getPos().add(self.pos);
        } else {
            return self.pos;
        }
    }
};

const RadioButtons = struct {
    container: ?*const Container,
    pos: Vec2,
    radio_size: Vec2,
    offset: Vec2,

    pub fn getPos(self: RadioButtons) Vec2 {
        if (self.container) |c| {
            return c.getPos().add(self.pos);
        } else {
            return self.pos;
        }
    }
};

const TabButtons = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    offset: Vec2,

    pub fn getPos(self: TabButtons) Vec2 {
        if (self.container) |c| {
            return c.getPos().add(self.pos);
        } else {
            return self.pos;
        }
    }
};

const Slider = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    text_left: [:0]const u8,
    text_right: [:0]const u8,

    pub fn getPos(self: Slider) Vec2 {
        if (self.container) |c| {
            return c.getPos().add(self.pos);
        } else {
            return self.pos;
        }
    }
};

const Spinner = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    text: [:0]const u8,

    pub fn getPos(self: Spinner) Vec2 {
        if (self.container) |c| {
            return c.getPos().add(self.pos);
        } else {
            return self.pos;
        }
    }
};

pub var sidebar: Container = .{
    .container = null,
    .pos = Vec2.init(0, 0),
    .size = Vec2.init(sidebar_width, 0),
    .title = "Options",
    .type = .Panel,
};

pub const controls: Container = .{
    .container = &sidebar,
    .pos = Vec2.init(20, 40),
    .size = Vec2.init(sidebar_width - 40, 260),
    .title = "Game controls",
    .type = .GroupBox,
};

pub const game_speed_box: Container = .{
    .container = &sidebar,
    .pos = Vec2.init(20, 320),
    .size = Vec2.init(sidebar_width - 40, 40),
    .title = "Game speed",
    .type = .GroupBox,
};

pub const clear_button: Button = .{
    .container = &controls,
    .pos = Vec2.init(20, 20),
    .size = Vec2.init(controls.size.x - 40, 40),
    .text = "Clear",
};

pub const randomize_button: Button = .{
    .container = &controls,
    .pos = Vec2.init(20, clear_button.pos.y + 60),
    .size = Vec2.init(controls.size.x - 40, 40),
    .text = "Randomize",
};

pub const pause_button: Button = .{
    .container = &controls,
    .pos = Vec2.init(20, randomize_button.pos.y + 60),
    .size = Vec2.init(controls.size.x - 40, 40),
    .text = "Pause",
};

pub const unpause_button: Button = .{
    .container = pause_button.container,
    .pos = pause_button.pos,
    .size = pause_button.size,
    .text = "Unpause",
};

pub const step_button: Button = .{
    .container = &controls,
    .pos = Vec2.init(20, pause_button.pos.y + 60),
    .size = Vec2.init(controls.size.x - 40, 40),
    .text = "Step",
};

pub const pattern_list: List = .{
    .container = &sidebar,
    .pos = Vec2.init(20, 40),
    .size = Vec2.init(sidebar_width - 40, 260),
};

pub const edit_mode_radio: RadioButtons = .{
    .container = null,
    .pos = Vec2.init(20, 20),
    .radio_size = Vec2.init(15, 15),
    .offset = Vec2.init(0, 20),
};

pub const sidebar_tab_buttons: TabButtons = .{
    .container = &sidebar,
    .pos = Vec2.init(-30, 30),
    .size = Vec2.init(32, 30),
    .offset = Vec2.init(0, 35),
};

pub const game_speed_slider: Slider = .{
    .container = &game_speed_box,
    .pos = Vec2.init(10, 10),
    .size = Vec2.init(sidebar_width - 60 - 100, 20),
    .text_left = "",
    .text_right = "",
};

pub const game_speed_spinner: Spinner = .{
    .container = &game_speed_box,
    .pos = Vec2.init(game_speed_slider.size.x + 20, 10),
    .size = Vec2.init(game_speed_box.size.x - game_speed_slider.size.x - 30, 20),
    .text = "",
};
