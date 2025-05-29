const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");
const Vec2 = rl.Vector2;
const Rect = rl.Rectangle;

pub const sidebar_width = 250;

pub const GuiElement = enum {
    Grid,
    Sidebar,

    TabSettings,
    TabPatterns,

    ClearButton,
    RandomizeButton,
    PauseButton,
    StepButton,

    GameSpeedSlider,
    GameSpeedSpinner,

    PatternList,
};

pub fn grabGuiElement(held_element: *?GuiElement, hovered_element: GuiElement, element: GuiElement) bool {
    const holding_mouse = rl.isMouseButtonDown(.left) or rl.isMouseButtonDown(.right);
    if (held_element.* == element or (held_element.* == null and hovered_element == element)) {
        held_element.* = if (holding_mouse) element else null;
        return true;
    }
    return false;
}

pub fn drawButton(b: Button, held_element: ?GuiElement) bool {
    const rect = rectFromVecs(b.getPos(), b.size);

    if (b.element == held_element) {
        return rg.guiButton(rect, b.text) != 0;
    } else if (held_element == null) {
        _ = rg.guiButton(rect, b.text);
        return false;
    } else {
        rg.guiLock();
        _ = rg.guiButton(rect, b.text);
        rg.guiUnlock();
        return false;
    }
}

pub fn drawCheckbox(c: Checkbox, checked: bool, held_element: ?GuiElement) bool {
    const rect = rectFromVecs(c.getPos(), c.box_size);

    var ch = checked;
    if (c.element == held_element) {
        _ = rg.guiCheckBox(rect, c.text, &ch);
    } else if (held_element == null) {
        _ = rg.guiCheckBox(rect, c.text, &ch);
    } else {
        rg.guiLock();
        _ = rg.guiCheckBox(rect, c.text, &ch);
        rg.guiUnlock();
    }
    return ch;
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

pub fn drawTabButtons(tb: TabButtons, tab_enum: anytype, held_element: ?GuiElement) struct { @TypeOf(tab_enum), ?@TypeOf(tab_enum) } {
    if (@typeInfo(@TypeOf(tab_enum)) != .@"enum") {
        @compileError("Expected enum type, found '" ++ @typeName(tab_enum) ++ "'");
    }

    var rect = rectFromVecs(tb.getPos(), tb.size);

    const fields = std.meta.fields(@TypeOf(tab_enum));

    var retval = tab_enum;
    var hovering: ?@TypeOf(tab_enum) = null;
    inline for (fields) |field| {
        if (@as(@TypeOf(tab_enum), @enumFromInt(field.value)).getGuiElement() == held_element) {
            if (rg.guiButton(rect, field.name) != 0) {
                retval = @enumFromInt(field.value);
            }
        } else if (held_element == null) {
            _ = rg.guiButton(rect, field.name);
        } else {
            rg.guiLock();
            _ = rg.guiButton(rect, field.name);
            rg.guiUnlock();
        }
        if (rl.checkCollisionPointRec(rl.getMousePosition(), rect)) {
            hovering = @enumFromInt(field.value);
        }

        rect.x += tb.offset.x;
        rect.y += tb.offset.y;
    }
    return .{ retval, hovering };
}

pub fn drawListView(list: List, items: [][*:0]const u8, scroll: *i32, active: *?usize, focused: *?usize, held_element: ?GuiElement) void {
    const rect = rectFromVecs(list.getPos(), list.size);
    var active_inner: i32 = if (active.*) |a| @intCast(a) else -1;
    var focused_inner: i32 = if (focused.*) |f| @intCast(f) else -1;

    if (list.element == held_element or held_element == null) {
        _ = rg.guiListViewEx(rect, items, scroll, &active_inner, &focused_inner);

        active.* = if (active_inner != -1) @intCast(active_inner) else null;
        focused.* = if (focused_inner != -1) @intCast(focused_inner) else null;
    } else {
        rg.guiLock();
        _ = rg.guiListViewEx(rect, items, scroll, &active_inner, &focused_inner);
        rg.guiUnlock();
    }
}

pub fn drawSlider(s: Slider, val: *f32, min: f32, max: f32, held_element: ?GuiElement) bool {
    const rect = rectFromVecs(s.getPos(), s.size);

    if (s.element == held_element) {
        return rg.guiSlider(rect, s.text_left, s.text_right, val, min, max) != 0;
    } else if (held_element == null) {
        _ = rg.guiSlider(rect, s.text_left, s.text_right, val, min, max);
        return false;
    } else {
        rg.guiLock();
        _ = rg.guiSlider(rect, s.text_left, s.text_right, val, min, max);
        rg.guiUnlock();
        return false;
    }
}

pub fn drawSpinner(sb: Spinner, val: *i32, min: i32, max: i32, editing: bool, held_element: ?GuiElement) bool {
    const rect = rectFromVecs(sb.getPos(), sb.size);

    if (sb.element == held_element) {
        return rg.guiSpinner(rect, sb.text, val, min, max, editing) != 0;
    } else if (held_element == null) {
        // giving it val for min and max both prevents it form editing the value and from drawing
        // the wrong, edited value for one frame
        return rg.guiSpinner(rect, sb.text, val, val.*, val.*, editing) != 0;
    } else {
        rg.guiLock();
        _ = rg.guiSpinner(rect, sb.text, val, min, max, editing);
        rg.guiUnlock();
        return editing;
    }
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
        const pos = self.getPos();
        return Rect.init(pos.x, pos.y, self.size.x, self.size.y);
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
    element: GuiElement,

    pub fn getRect(self: Button) Rect {
        const pos = self.getPos();
        return Rect.init(pos.x, pos.y, self.size.x, self.size.y);
    }

    pub fn getPos(self: Button) Vec2 {
        if (self.container) |c| {
            return c.getPos().add(self.pos);
        } else {
            return self.pos;
        }
    }
};

const Checkbox = struct {
    container: ?*const Container,
    pos: Vec2,
    box_size: Vec2,
    text: [:0]const u8,
    element: GuiElement,

    pub fn getRect(self: Checkbox) Rect {
        const pos = self.getPos();
        return Rect.init(pos.x, pos.y, self.box_size.x, self.box_size.y);
    }

    pub fn getPos(self: Checkbox) Vec2 {
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
    element: GuiElement,

    pub fn getRect(self: List) Rect {
        const pos = self.getPos();
        return Rect.init(pos.x, pos.y, self.size.x, self.size.y);
    }

    pub fn getPos(self: List) Vec2 {
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
    element: GuiElement,

    pub fn getRect(self: Slider) Rect {
        const pos = self.getPos();
        return Rect.init(pos.x, pos.y, self.size.x, self.size.y);
    }

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
    element: GuiElement,

    pub fn getRect(self: Spinner) Rect {
        const pos = self.getPos();
        return Rect.init(pos.x, pos.y, self.size.x, self.size.y);
    }

    pub fn getPos(self: Spinner) Vec2 {
        if (self.container) |c| {
            return c.getPos().add(self.pos);
        } else {
            return self.pos;
        }
    }
};

pub const SidebarTabs = enum {
    Settings,
    Patterns,
    pub fn getGuiElement(self: SidebarTabs) GuiElement {
        return switch (self) {
            .Settings => .TabSettings,
            .Patterns => .TabPatterns,
        };
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
    .element = .ClearButton,
};

pub const randomize_button: Button = .{
    .container = &controls,
    .pos = Vec2.init(20, clear_button.pos.y + 60),
    .size = Vec2.init(controls.size.x - 40, 40),
    .text = "Randomize",
    .element = .RandomizeButton,
};

pub const pause_button: Button = .{
    .container = &controls,
    .pos = Vec2.init(20, randomize_button.pos.y + 60),
    .size = Vec2.init(controls.size.x - 40, 40),
    .text = "Pause",
    .element = .PauseButton,
};

pub const unpause_button: Button = .{
    .container = pause_button.container,
    .pos = pause_button.pos,
    .size = pause_button.size,
    .text = "Unpause",
    .element = .PauseButton,
};

pub const step_button: Button = .{
    .container = &controls,
    .pos = Vec2.init(20, pause_button.pos.y + 60),
    .size = Vec2.init(controls.size.x - 40, 40),
    .text = "Step",
    .element = .StepButton,
};

pub const edit_mode_checkbox: Checkbox = .{
    .container = null,
    .pos = Vec2.init(20, 20),
    .box_size = Vec2.init(15, 15),
    .text = "Editing",
    .element = .EditMode,
};

pub const pattern_list: List = .{
    .container = &sidebar,
    .pos = Vec2.init(20, 40),
    .size = Vec2.init(sidebar_width - 40, 260),
    .element = .PatternList,
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
    .element = .GameSpeedSlider,
};

pub const game_speed_spinner: Spinner = .{
    .container = &game_speed_box,
    .pos = Vec2.init(game_speed_slider.size.x + 20, 10),
    .size = Vec2.init(game_speed_box.size.x - game_speed_slider.size.x - 30, 20),
    .text = "",
    .element = .GameSpeedSpinner,
};
