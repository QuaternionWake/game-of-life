const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");
const Vec2 = rl.Vector2;
const Rect = rl.Rectangle;

const GameType = @import("main.zig").GameType;

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
pub var sidebar_tab: SidebarTabs = .Settings;

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

pub fn drawTabButtons(tb: TabButtons) ?tb.tabs {
    var rect = tb.getRect();

    const fields = std.meta.fields(tb.tabs);

    var hovering: ?tb.tabs = null;
    inline for (fields) |field| {
        if (@as(tb.tabs, @enumFromInt(field.value)).getGuiElement() == held_element) {
            if (rg.guiButton(rect, field.name) != 0) {
                sidebar_tab = @enumFromInt(field.value);
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
    return hovering;
}

pub fn drawListView(list: List, items: [][*:0]const u8) void {
    var active_inner: i32 = if (list.data.active) |a| @intCast(a) else -1;
    var focused_inner: i32 = if (list.data.focused) |f| @intCast(f) else -1;

    if (list.element == held_element or held_element == null) {
        _ = rg.guiListViewEx(list.getRect(), items, &list.data.scroll, &active_inner, &focused_inner);

        list.data.active = if (active_inner != -1) @intCast(active_inner) else null;
        list.data.focused = if (focused_inner != -1) @intCast(focused_inner) else null;
    } else {
        rg.guiLock();
        _ = rg.guiListViewEx(list.getRect(), items, &list.data.scroll, &active_inner, &focused_inner);
        rg.guiUnlock();
    }
}

pub fn drawSlider(s: Slider) bool {
    if (s.element == held_element) {
        return rg.guiSlider(s.getRect(), s.text_left, s.text_right, &s.data.value, s.data.min, s.data.max) != 0;
    } else if (held_element == null) {
        _ = rg.guiSlider(s.getRect(), s.text_left, s.text_right, &s.data.value, s.data.min, s.data.max);
        return false;
    } else {
        rg.guiLock();
        _ = rg.guiSlider(s.getRect(), s.text_left, s.text_right, &s.data.value, s.data.min, s.data.max);
        rg.guiUnlock();
        return false;
    }
}

pub fn drawSpinner(sb: Spinner) void {
    if (sb.element == held_element) {
        sb.data.editing = rg.guiSpinner(sb.getRect(), sb.text, &sb.data.value, sb.data.min, sb.data.max, sb.data.editing) != 0;
    } else if (held_element == null) {
        // giving it val for min and max both prevents it form editing the value and from drawing
        // the wrong, edited value for one frame
        sb.data.editing = rg.guiSpinner(sb.getRect(), sb.text, &sb.data.value, sb.data.value, sb.data.value, sb.data.editing) != 0;
    } else {
        rg.guiLock();
        _ = rg.guiSpinner(sb.getRect(), sb.text, &sb.data.value, sb.data.min, sb.data.max, sb.data.editing);
        rg.guiUnlock();
    }
}

pub fn drawDropdown(d: Dropdown) bool {
    const fields = std.meta.fields(d.contents);
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

    var selected_idx: i32 = @intCast(d.data.selected);

    if (d.element == held_element) {
        _ = rg.guiDropdownBox(d.getRect(), &field_names, &selected_idx, d.data.editing);
        if (rl.checkCollisionPointRec(rl.getMousePosition(), d.getRect()) and rl.isMouseButtonReleased(.left)) {
            d.data.editing = !d.data.editing;
        }
    } else if (held_element == null) {
        _ = rg.guiDropdownBox(d.getRect(), &field_names, &selected_idx, d.data.editing);
    } else {
        rg.guiLock();
        _ = rg.guiDropdownBox(d.getRect(), &field_names, &selected_idx, d.data.editing);
        rg.guiUnlock();
    }

    if (selected_idx != d.data.selected) {
        d.data.selected = @intCast(selected_idx);
        return true;
    }
    return false;
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

const List = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    data: *ListData,
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

const ListData = struct {
    scroll: i32 = 0,
    active: ?usize = null,
    focused: ?usize = null,
};

const TabButtons = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    offset: Vec2,
    tabs: type,

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
    data: *SliderData,
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

const SliderData = struct {
    min: f32,
    max: f32,
    value: f32,
};

const Spinner = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    text: [:0]const u8,
    data: *SpinnerData,
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

const SpinnerData = struct {
    min: i32,
    max: i32,
    value: i32,
    editing: bool,
};

const Dropdown = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    contents: type,
    data: *DropdownData,
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

    pub fn getSelected(self: Dropdown) self.contents {
        return @enumFromInt(self.data.selected);
    }
};

const DropdownData = struct {
    selected: usize = 0,
    editing: bool = false,
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

pub const pattern_list: List = .{
    .container = &sidebar,
    .pos = Vec2.init(20, 40),
    .size = Vec2.init(sidebar_width - 40, 260),
    .data = &pattern_list_data,
    .element = .PatternList,
};

var pattern_list_data: ListData = .{};

pub const sidebar_tab_buttons: TabButtons = .{
    .container = &sidebar,
    .pos = Vec2.init(-30, 30),
    .size = Vec2.init(32, 30),
    .offset = Vec2.init(0, 35),
    .tabs = SidebarTabs,
};

pub const game_speed_slider: Slider = .{
    .container = &game_speed_box,
    .pos = Vec2.init(10, 10),
    .size = Vec2.init(sidebar_width - 60 - 100, 20),
    .text_left = "",
    .text_right = "",
    .data = &game_speed_slider_data,
    .element = .GameSpeedSlider,
};

var game_speed_slider_data: SliderData = .{
    .min = 1,
    .max = 240,
    .value = 60,
};

pub const game_speed_spinner: Spinner = .{
    .container = &game_speed_box,
    .pos = Vec2.init(game_speed_slider.size.x + 20, 10),
    .size = Vec2.init(game_speed_box.size.x - game_speed_slider.size.x - 30, 20),
    .text = "",
    .data = &game_speed_spinner_data,
    .element = .GameSpeedSpinner,
};

var game_speed_spinner_data: SpinnerData = .{
    .min = 0,
    .max = 240,
    .value = 60,
    .editing = false,
};

pub const game_type_dropdown: Dropdown = .{
    .container = &sidebar,
    .pos = Vec2.init(20, 40),
    .size = Vec2.init(sidebar_width - 40, 40),
    .contents = GameType,
    .data = &game_type_dropdown_data,
    .element = .GameTypeDropdown,
};

var game_type_dropdown_data: DropdownData = .{
    .selected = @intFromEnum(GameType.@"Static Array"),
};
