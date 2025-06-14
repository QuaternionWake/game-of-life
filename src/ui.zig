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
    TabGameTypes,

    ClearButton,
    RandomizeButton,
    PauseButton,
    StepButton,

    GameSpeedSlider,
    GameSpeedSpinner,

    PatternList,

    GameTypeDropdown,
};

pub var held_element: ?GuiElement = null;
pub var hovered_element: GuiElement = .Grid;

pub fn grabGuiElement(element: anytype) void {
    const holding_mouse = rl.isMouseButtonDown(.left) or rl.isMouseButtonDown(.right);
    if (canGrab(element.getElement())) {
        held_element = if (holding_mouse) element.getElement() else null;
    }
}

pub fn canGrab(element: GuiElement) bool {
    return held_element == element or (held_element == null and hovered_element == element);
}

pub fn hoverGuiElement(element: anytype) void {
    const mouse_pos = rl.getMousePosition();
    if (rl.checkCollisionPointRec(mouse_pos, element.getRect())) {
        hovered_element = element.getElement();
    }
}

pub fn drawButton(b: Button) bool {
    if (b.element == held_element) {
        return rg.guiButton(b.getRect(), b.text) != 0;
    } else if (held_element == null) {
        _ = rg.guiButton(b.getRect(), b.text);
        return false;
    } else {
        rg.guiLock();
        _ = rg.guiButton(b.getRect(), b.text);
        rg.guiUnlock();
        return false;
    }
}

pub fn drawCheckbox(c: Checkbox, checked: bool) bool {
    var ch = checked;
    if (c.element == held_element) {
        _ = rg.guiCheckBox(c.getRect(), c.text, &ch);
    } else if (held_element == null) {
        _ = rg.guiCheckBox(c.getRect(), c.text, &ch);
    } else {
        rg.guiLock();
        _ = rg.guiCheckBox(c.getRect(), c.text, &ch);
        rg.guiUnlock();
    }
    return ch;
}

pub fn drawContainer(c: Container) void {
    switch (c.type) {
        .Panel => {
            _ = rg.guiPanel(c.getRect(), c.title);
        },
        .GroupBox => {
            _ = rg.guiGroupBox(c.getRect(), c.title);
        },
    }
}

pub fn drawTabButtons(tb: TabButtons, tab_enum: anytype) struct { @TypeOf(tab_enum), ?@TypeOf(tab_enum) } {
    if (@typeInfo(@TypeOf(tab_enum)) != .@"enum") {
        @compileError("Expected enum type, found '" ++ @typeName(tab_enum) ++ "'");
    }

    var rect = tb.getRect();

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

pub fn drawListView(list: List, items: [][*:0]const u8, scroll: *i32, active: *?usize, focused: *?usize) void {
    var active_inner: i32 = if (active.*) |a| @intCast(a) else -1;
    var focused_inner: i32 = if (focused.*) |f| @intCast(f) else -1;

    if (list.element == held_element or held_element == null) {
        _ = rg.guiListViewEx(list.getRect(), items, scroll, &active_inner, &focused_inner);

        active.* = if (active_inner != -1) @intCast(active_inner) else null;
        focused.* = if (focused_inner != -1) @intCast(focused_inner) else null;
    } else {
        rg.guiLock();
        _ = rg.guiListViewEx(list.getRect(), items, scroll, &active_inner, &focused_inner);
        rg.guiUnlock();
    }
}

pub fn drawSlider(s: Slider, val: *f32, min: f32, max: f32) bool {
    if (s.element == held_element) {
        return rg.guiSlider(s.getRect(), s.text_left, s.text_right, val, min, max) != 0;
    } else if (held_element == null) {
        _ = rg.guiSlider(s.getRect(), s.text_left, s.text_right, val, min, max);
        return false;
    } else {
        rg.guiLock();
        _ = rg.guiSlider(s.getRect(), s.text_left, s.text_right, val, min, max);
        rg.guiUnlock();
        return false;
    }
}

pub fn drawSpinner(sb: Spinner, val: *i32, min: i32, max: i32, editing: bool) bool {
    if (sb.element == held_element) {
        return rg.guiSpinner(sb.getRect(), sb.text, val, min, max, editing) != 0;
    } else if (held_element == null) {
        // giving it val for min and max both prevents it form editing the value and from drawing
        // the wrong, edited value for one frame
        return rg.guiSpinner(sb.getRect(), sb.text, val, val.*, val.*, editing) != 0;
    } else {
        rg.guiLock();
        _ = rg.guiSpinner(sb.getRect(), sb.text, val, min, max, editing);
        rg.guiUnlock();
        return editing;
    }
}

pub fn drawDropdown(d: Dropdown, selected: anytype, edit_mode: *bool) @TypeOf(selected) {
    if (@typeInfo(@TypeOf(selected)) != .@"enum") {
        @compileError("Expected enum type, found '" ++ @typeName(selected) ++ "'");
    }

    const fields = std.meta.fields(@TypeOf(selected));
    const field_names = comptime blk: {
        var len = 0;
        for (fields) |field| {
            len += field.name.len + 1; // +1 for semicolon / null terminator
        }
        var names: [len:0]u8 = undefined;
        var offset = 0;
        for (fields) |field| {
            std.mem.copyForwards(u8, names[offset..], field.name);
            offset += field.name.len + 1;
            names[offset - 1] = ';';
        }
        names[len - 1] = 0;
        break :blk names;
    };

    var selected_idx: i32 = @intFromEnum(selected);

    if (d.element == held_element) {
        _ = rg.guiDropdownBox(d.getRect(), &field_names, &selected_idx, edit_mode.*);
        if (rl.checkCollisionPointRec(rl.getMousePosition(), d.getRect()) and rl.isMouseButtonReleased(.left)) {
            edit_mode.* = !edit_mode.*;
        }
    } else if (held_element == null) {
        _ = rg.guiDropdownBox(d.getRect(), &field_names, &selected_idx, edit_mode.*);
    } else {
        rg.guiLock();
        _ = rg.guiDropdownBox(d.getRect(), &field_names, &selected_idx, edit_mode.*);
        rg.guiUnlock();
    }

    return @enumFromInt(selected_idx);
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
    element: GuiElement,

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

    pub fn getElement(self: Container) GuiElement {
        return self.element;
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

    pub fn getElement(self: Button) GuiElement {
        return self.element;
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

    pub fn getElement(self: Checkbox) GuiElement {
        return self.element;
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

    pub fn getElement(self: List) GuiElement {
        return self.element;
    }
};

const TabButtons = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    offset: Vec2,

    pub fn getRect(self: TabButtons) Rect {
        const pos = self.getPos();
        return Rect.init(pos.x, pos.y, self.size.x, self.size.y);
    }

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

    pub fn getElement(self: Slider) GuiElement {
        return self.element;
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

    pub fn getElement(self: Spinner) GuiElement {
        return self.element;
    }
};

const Dropdown = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    element: GuiElement,

    pub fn getRect(self: Dropdown) Rect {
        const pos = self.getPos();
        return Rect.init(pos.x, pos.y, self.size.x, self.size.y);
    }

    pub fn getPos(self: Dropdown) Vec2 {
        if (self.container) |c| {
            return c.getPos().add(self.pos);
        } else {
            return self.pos;
        }
    }

    pub fn getElement(self: Dropdown) GuiElement {
        return self.element;
    }
};

pub const SidebarTabs = enum {
    Settings,
    Patterns,
    GameTypes,
    pub fn getGuiElement(self: SidebarTabs) GuiElement {
        return switch (self) {
            .Settings => .TabSettings,
            .Patterns => .TabPatterns,
            .GameTypes => .TabGameTypes,
        };
    }
};

// dummy struct for consistency
const Grid = struct {
    pub fn getElement(_: Grid) GuiElement {
        return .Grid;
    }
};

pub const grid: Grid = .{};

pub var sidebar: Container = .{
    .container = null,
    .pos = Vec2.init(0, 0),
    .size = Vec2.init(sidebar_width, 0),
    .title = "Options",
    .type = .Panel,
    .element = .Sidebar,
};

pub const controls: Container = .{
    .container = &sidebar,
    .pos = Vec2.init(20, 40),
    .size = Vec2.init(sidebar_width - 40, 260),
    .title = "Game controls",
    .type = .GroupBox,
    .element = .Sidebar,
};

pub const game_speed_box: Container = .{
    .container = &sidebar,
    .pos = Vec2.init(20, 320),
    .size = Vec2.init(sidebar_width - 40, 40),
    .title = "Game speed",
    .type = .GroupBox,
    .element = .Sidebar,
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

pub const game_type_dropdown: Dropdown = .{
    .container = &sidebar,
    .pos = Vec2.init(20, 40),
    .size = Vec2.init(sidebar_width - 40, 40),
    .element = .GameTypeDropdown,
};
