const std = @import("std");
const EnumArray = std.EnumArray;

const rl = @import("raylib");
const rg = @import("raygui");
const Vec2 = rl.Vector2;
const RlRect = rl.Rectangle;

const Rect = @import("rect.zig");

const GameType = @import("main.zig").GameType;
const Category = @import("PatternLibrary.zig").Category;
const Wrap = @import("games/DynamicArray.zig").Wrap;
const LoadableFormats = @import("file-formats.zig").LoadableFormats;

pub const GuiElement = enum {
    Grid,
    Sidebar,

    SidebarTabButtons,

    ClearButton,
    RandomizeButton,
    PauseButton,
    StepButton,

    GameSpeedSlider,
    GameSpeedSpinner,

    PatternList,
    PatternNameInput,
    SavePatternButton,
    LoadPathInput,
    LoadPatternExtension,
    LoadPatternButton,
    LoadFromClipboardButton,

    GameTypeDropdown,

    DynamicArrayWidthSpinner,
    DynamicArrayHeightSpinner,
    DynamicArrayXWrapDropdown,
    DynamicArrayYWrapDropdown,
};

pub const SidebarTabs = enum {
    Settings,
    Patterns,
    GameTypes,
};

pub var held_element: ?GuiElement = null;
pub var previous_held_element: ?GuiElement = null;
pub var hovered_element: GuiElement = .Grid;
pub var sidebar_tab: SidebarTabs = .Settings;

const top_level_elements = .{
    sidebar_tab_buttons,
    sidebar,
    grid,
};

const settings_elements = .{
    clear_button,
    randomize_button,
    pause_button,
    unpause_button,
    step_button,
    game_speed_slider,
    game_speed_spinner,

    controls,
    game_speed_box,
};

const pattern_list_elements = .{
    pattern_list,
    pattern_name_input,
    save_pattern_button,
    pattern_load_path_input,
    load_pattern_extension_dropdown,
    load_pattern_button,
    load_from_clipboard_button,
};

const game_type_elements = .{
    game_type_dropdown,
};

const static_game_elements = .{};

const dynamic_game_elemnts = .{
    dynamic_array_height_spinner,
    dynamic_array_width_spinner,
    dynamic_array_xwrap_dropdown,
    dynamic_array_ywrap_dropdown,
};

const hashset_game_elements = .{};

const hashfast_game_elements = .{};

pub fn grabElement() void {
    previous_held_element = held_element;
    _ = grabElementGroup(top_level_elements);

    switch (sidebar_tab) {
        .Settings => _ = grabElementGroup(settings_elements),
        .Patterns => _ = grabElementGroup(pattern_list_elements),
        .GameTypes => if (!grabElementGroup(game_type_elements)) {
            switch (game_type_dropdown.getSelected()) {
                .@"Static Array" => _ = grabElementGroup(static_game_elements),
                .@"Dynamic Array" => _ = grabElementGroup(dynamic_game_elemnts),
                .Hashset => _ = grabElementGroup(hashset_game_elements),
                .@"Hashset (faster (sometimes))" => _ = grabElementGroup(hashfast_game_elements),
            }
        },
    }

    if (rl.isMouseButtonDown(.left) or rl.isMouseButtonDown(.right)) {
        if (held_element != null) {
            return;
        } else {
            held_element = hovered_element;
        }
    } else {
        held_element = null;
    }
}

fn grabElementGroup(elements: anytype) bool {
    const mouse_pos = rl.getMousePosition();
    inline for (elements) |e| {
        if (e.containsPoint(mouse_pos)) {
            hovered_element = e.element;
            return true;
        }
    }
    return false;
}

pub fn canGrab(e: anytype) bool {
    return held_element == e.element or (held_element == null and hovered_element == e.element);
}

pub fn isHolding(e: anytype) bool {
    return held_element == e.element or previous_held_element == e.element;
}

/// Returns true when clicked
pub fn drawButton(b: Button) bool {
    if (isHolding(b)) {
        return rg.button(b.getRect(), b.text);
    } else if (canGrab(b)) {
        _ = rg.button(b.getRect(), b.text);
        return false;
    } else {
        rg.lock();
        _ = rg.button(b.getRect(), b.text);
        rg.unlock();
        return false;
    }
}

pub fn drawContainer(c: Container) void {
    switch (c.type) {
        .Panel => {
            _ = rg.panel(c.getRect(), c.title);
        },
        .GroupBox => {
            _ = rg.groupBox(c.getRect(), c.title);
        },
    }
}

pub fn drawTabButtons(tb: TabButtons) ?tb.tabs {
    var rect = tb.getRect();

    const fields = std.meta.fields(tb.tabs);

    var result: ?tb.tabs = null;
    inline for (fields) |field| {
        if (isHolding(tb)) {
            if (rg.button(rect, field.name)) {
                result = @enumFromInt(field.value);
            }
        } else if (canGrab(tb)) {
            _ = rg.button(rect, field.name);
        } else {
            rg.lock();
            _ = rg.button(rect, field.name);
            rg.unlock();
        }

        rect.x += tb.offset.x;
        rect.y += tb.offset.y;
    }
    return result;
}

pub fn drawListView(list: List, items: [][*:0]const u8) void {
    var active_inner: i32 = if (list.data.active) |a| @intCast(a) else -1;
    var focused_inner: i32 = if (list.data.focused) |f| @intCast(f) else -1;

    if (isHolding(list)) {
        _ = rg.listViewEx(list.getRect(), items, &list.data.scroll, &active_inner, &focused_inner);

        list.data.active = if (active_inner != -1) @intCast(active_inner) else null;
        list.data.focused = if (focused_inner != -1) @intCast(focused_inner) else null;
    } else if (canGrab(list)) {
        _ = rg.listViewEx(list.getRect(), items, &list.data.scroll, &active_inner, &focused_inner);
    } else {
        rg.lock();
        _ = rg.listViewEx(list.getRect(), items, &list.data.scroll, &active_inner, &focused_inner);
        rg.unlock();
    }
}

pub fn drawTabbedList(list: TabbedList, items: EnumArray(list.tabs, [][*:0]const u8)) void {
    if (drawTabButtons(list.getTabButtons())) |tab| {
        list.data.tab = @intFromEnum(tab);
    }

    var list_data_buf: List.Data = undefined;
    drawListView(list.getListView(&list_data_buf), items.get(list.getTab()));
    list.data.scroll[list.data.tab] = list_data_buf.scroll;
    list.data.active = list_data_buf.active;
    list.data.focused = list_data_buf.focused;
}

/// Returns true when editing stops.
pub fn drawTextInput(ti: TextInput) bool {
    const previous_editing = ti.data.editing;
    if (ti.data.editing or canGrab(ti)) {
        if (rg.textBox(ti.getRect(), ti.data.text_buffer, @intCast(ti.data.text_buffer.len - 1), ti.data.editing)) {
            ti.data.editing = !ti.data.editing;
        }
    } else {
        rg.lock();
        _ = rg.textBox(ti.getRect(), ti.data.text_buffer, @intCast(ti.data.text_buffer.len - 1), ti.data.editing);
        rg.unlock();
    }
    return previous_editing and !ti.data.editing;
}

/// Returns true when value has changed
pub fn drawSlider(s: Slider) bool {
    const old_value = s.data.value;
    if (canGrab(s)) {
        _ = rg.slider(s.getRect(), s.text_left, s.text_right, &s.data.value, s.data.min, s.data.max);
    } else {
        rg.lock();
        _ = rg.slider(s.getRect(), s.text_left, s.text_right, &s.data.value, s.data.min, s.data.max);
        rg.unlock();
    }
    return old_value != s.data.value;
}

/// If `return_on_change` is true - retruns true whenever value changes.
/// Otherwise, returns true when editing is finished.
pub fn drawSpinner(s: Spinner, return_on_change: bool) bool {
    const old_value = s.data.value;
    var stopped_editing = false;
    if (isHolding(s)) {
        if (rg.spinner(s.getRect(), s.text, &s.data.value, s.data.min, s.data.max, s.data.editing) != 0) {
            s.data.editing = !s.data.editing;
            stopped_editing = !s.data.editing;
        }
    } else if (canGrab(s)) {
        // giving it val for min and max both prevents it form editing the value and from drawing
        // the wrong, edited value for one frame
        if (rg.spinner(s.getRect(), s.text, &s.data.value, s.data.value, s.data.value, s.data.editing) != 0) {
            s.data.editing = !s.data.editing;
            stopped_editing = !s.data.editing;
        }
    } else {
        rg.lock();
        _ = rg.spinner(s.getRect(), s.text, &s.data.value, s.data.min, s.data.max, s.data.editing);
        rg.unlock();
    }
    if (return_on_change) {
        return old_value != s.data.value;
    } else {
        return stopped_editing;
    }
}

/// Returns true when value has changed
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

    if (isHolding(d)) {
        if (rg.dropdownBox(d.getRect(), &field_names, &selected_idx, d.data.editing) != 0) {
            d.data.editing = !d.data.editing;
        }
    } else if (canGrab(d)) {
        if (rg.dropdownBox(d.getRect(), &field_names, &selected_idx, d.data.editing) != 0) {
            d.data.editing = !d.data.editing;
        }
    } else {
        rg.lock();
        _ = rg.dropdownBox(d.getRect(), &field_names, &selected_idx, d.data.editing);
        rg.unlock();
    }

    if (selected_idx != d.data.selected) {
        d.data.selected = @intCast(selected_idx);
        return true;
    }
    return false;
}

const Container = struct {
    rect: Rect,
    title: [:0]const u8,
    type: enum { Panel, GroupBox },
    element: GuiElement,

    pub fn getRect(self: Container) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Container, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }
};

const Button = struct {
    rect: Rect,
    text: [:0]const u8,
    element: GuiElement,

    pub fn getRect(self: Button) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Button, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }
};

const List = struct {
    rect: Rect,
    data: *Data,
    element: GuiElement,

    pub fn getRect(self: List) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: List, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }

    const Data = struct {
        scroll: i32 = 0,
        active: ?usize = null,
        focused: ?usize = null,
    };
};

const TabbedList = struct {
    rect: Rect,
    tab_height: f32,
    tabs: type,
    data: *Data,
    element: GuiElement,

    pub fn getRect(self: TabbedList) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: TabbedList, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }

    pub fn getTab(self: TabbedList) self.tabs {
        return @enumFromInt(self.data.tab);
    }

    pub fn getTabButtons(self: TabbedList) TabButtons {
        const tab_count = @typeInfo(self.tabs).@"enum".fields.len;
        const tab_bar_width = 180; // FIXME: properly parametrize the ui structs so we can do this right
        const tab_gap = 3;
        const tab_width = (tab_bar_width - tab_gap * (tab_count - 1)) / tab_count;

        return .{
            .rect = .{
                .parent = &self.rect,
                .x = .{ .left = 0 },
                .y = .{ .top = 0 },
                .width = .{ .amount = tab_width },
                .height = .{ .amount = self.tab_height },
            },
            .offset = Vec2.init(tab_width + tab_gap, 0),
            .tabs = self.tabs,
            .element = self.element,
        };
    }

    pub fn getListView(self: TabbedList, data_buf: *List.Data) List {
        data_buf.* = self.data.getListData(self.data.tab);
        return .{
            .rect = .{
                .parent = &self.rect,
                .x = .{ .left = 0 },
                .y = .{ .top = self.tab_height },
                .width = .{ .relative = 0 },
                .height = .{ .relative = -self.tab_height },
            },
            .data = data_buf,
            .element = self.element,
        };
    }

    const Data = struct {
        scroll: []i32,
        active: ?usize = null,
        focused: ?usize = null,
        tab: usize = 0,

        pub fn getListData(self: Data, tab: usize) List.Data {
            return .{
                .scroll = self.scroll[tab],
                .active = if (tab == self.tab) self.active else null,
                .focused = if (tab == self.tab) self.focused else null,
            };
        }
    };
};

const TabButtons = struct {
    rect: Rect,
    offset: Vec2,
    tabs: type,
    element: GuiElement,

    pub fn getRect(self: TabButtons) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: TabButtons, point: Vec2) bool {
        const len = std.meta.fields(self.tabs).len;
        var rect = self.getRect();

        for (0..len) |_| {
            if (rl.checkCollisionPointRec(point, rect)) {
                return true;
            }
            rect.x += self.offset.x;
            rect.y += self.offset.y;
        }

        return false;
    }
};

const Slider = struct {
    rect: Rect,
    text_left: [:0]const u8,
    text_right: [:0]const u8,
    data: *Data,
    element: GuiElement,

    pub fn getRect(self: Slider) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Slider, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }

    const Data = struct {
        min: f32,
        max: f32,
        value: f32,
    };
};

const Spinner = struct {
    rect: Rect,
    text: [:0]const u8,
    data: *Data,
    element: GuiElement,

    pub fn getRect(self: Spinner) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Spinner, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }

    const Data = struct {
        min: i32,
        max: i32,
        value: i32,
        editing: bool = false,
    };
};

const Dropdown = struct {
    rect: Rect,
    contents: type,
    data: *Data,
    element: GuiElement,

    pub fn getRect(self: Dropdown) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Dropdown, point: Vec2) bool {
        var rect = self.getRect();
        if (self.data.editing) {
            rect.height += @floatFromInt(rg.getStyle(.dropdownbox, .{ .default = .text_spacing }));
            const len = std.meta.fields(self.contents).len;
            rect.height *= len + 1;
        }

        return rl.checkCollisionPointRec(point, rect);
    }

    pub fn getSelected(self: Dropdown) self.contents {
        return @enumFromInt(self.data.selected);
    }

    const Data = struct {
        selected: usize = 0,
        editing: bool = false,
    };
};

const TextInput = struct {
    rect: Rect,
    data: *Data,
    element: GuiElement,

    pub fn getRect(self: TextInput) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: TextInput, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }

    const Data = struct {
        text_buffer: [:0]u8,
        editing: bool = false,
    };
};

// dummy struct for consistency
const Grid = struct {
    element: GuiElement = .Grid,

    pub fn getRect() RlRect {
        return RlRect.init(0, 0, @floatFromInt(rl.getScreenWidth()), @floatFromInt(rl.getScreenHeight()));
    }

    pub fn containsPoint(_: Grid, _: Vec2) bool {
        return true;
    }
};

pub const grid: Grid = .{};

pub const sidebar: Container = .{
    .rect = .{
        .parent = null,
        .x = .{ .right = 0 },
        .y = .{ .top = 0 },
        .width = .{ .amount = 250 },
        .height = .{ .ratio = 1 },
    },
    .title = "Options",
    .type = .Panel,
    .element = .Sidebar,
};

pub const controls: Container = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 40 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 260 },
    },
    .title = "Game controls",
    .type = .GroupBox,
    .element = .Sidebar,
};

pub const game_speed_box: Container = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 320 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 40 },
    },
    .title = "Game speed",
    .type = .GroupBox,
    .element = .Sidebar,
};

pub const clear_button: Button = .{
    .rect = .{
        .parent = &controls.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 20 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 40 },
    },
    .text = "Clear",
    .element = .ClearButton,
};

pub const randomize_button: Button = .{
    .rect = .{
        .parent = &controls.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 80 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 40 },
    },
    .text = "Randomize",
    .element = .RandomizeButton,
};

pub const pause_button: Button = .{
    .rect = .{
        .parent = &controls.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 140 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 40 },
    },
    .text = "Pause",
    .element = .PauseButton,
};

pub const unpause_button: Button = .{
    .rect = pause_button.rect,
    .text = "Unpause",
    .element = .PauseButton,
};

pub const step_button: Button = .{
    .rect = .{
        .parent = &controls.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 200 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 40 },
    },
    .text = "Step",
    .element = .StepButton,
};

pub const pattern_list: TabbedList = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 40 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 250 },
    },
    .tab_height = 20,
    .tabs = Category,
    .data = &pattern_list_data,
    .element = .PatternList,
};

var pattern_list_data: TabbedList.Data = .{
    .scroll = &pattern_list_scroll,
};

var pattern_list_scroll: [@typeInfo(pattern_list.tabs).@"enum".fields.len]i32 = @splat(0);

pub const pattern_name_input: TextInput = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .left = 20 },
        .y = .{ .top = 310 },
        .width = .{ .relative = -85 },
        .height = .{ .amount = 25 },
    },
    .data = &pattern_name_input_data,
    .element = .PatternNameInput,
};

var pattern_name_input_data: TextInput.Data = .{
    .text_buffer = &pattern_name_buf,
};

var pattern_name_buf: [32:0]u8 = .{0} ** 32;

pub const save_pattern_button: Button = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .right = -20 },
        .y = .{ .top = 310 },
        .width = .{ .amount = 40 },
        .height = .{ .amount = 25 },
    },
    .text = "Save",
    .element = .SavePatternButton,
};

pub const pattern_load_path_input: TextInput = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .left = 20 },
        .y = .{ .top = 340 },
        .width = .{ .relative = -150 },
        .height = .{ .amount = 25 },
    },
    .data = &pattern_load_path_input_data,
    .element = .LoadPathInput,
};

var pattern_load_path_input_data: TextInput.Data = .{
    .text_buffer = &pattern_load_path_buf,
};

var pattern_load_path_buf: [32:0]u8 = .{0} ** 32;

pub const load_pattern_extension_dropdown: Dropdown = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .right = -65 },
        .y = .{ .top = 340 },
        .width = .{ .amount = 60 },
        .height = .{ .amount = 25 },
    },
    .contents = LoadableFormats,
    .data = &load_pattern_extension_dropdown_data,
    .element = .LoadPatternExtension,
};

var load_pattern_extension_dropdown_data: Dropdown.Data = .{};

pub const load_pattern_button: Button = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .right = -20 },
        .y = .{ .top = 340 },
        .width = .{ .amount = 40 },
        .height = .{ .amount = 25 },
    },
    .text = "Load",
    .element = .LoadPatternButton,
};

pub const load_from_clipboard_button: Button = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 380 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 40 },
    },
    .text = "Load from clipboard",
    .element = .LoadFromClipboardButton,
};

pub const sidebar_tab_buttons: TabButtons = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .left = -30 },
        .y = .{ .top = 30 },
        .width = .{ .amount = 32 },
        .height = .{ .amount = 30 },
    },
    .offset = Vec2.init(0, 35),
    .tabs = SidebarTabs,
    .element = .SidebarTabButtons,
};

pub const game_speed_slider: Slider = .{
    .rect = .{
        .parent = &game_speed_box.rect,
        .x = .{ .left = 10 },
        .y = .{ .middle = 0 },
        .width = .{ .relative = -115 },
        .height = .{ .relative = -20 },
    },
    .text_left = "",
    .text_right = "",
    .data = &game_speed_slider_data,
    .element = .GameSpeedSlider,
};

var game_speed_slider_data: Slider.Data = .{
    .min = 1,
    .max = 240,
    .value = 60,
};

pub const game_speed_spinner: Spinner = .{
    .rect = .{
        .parent = &game_speed_box.rect,
        .x = .{ .right = -10 },
        .y = .{ .middle = 0 },
        .width = .{ .amount = 90 },
        .height = .{ .relative = -20 },
    },
    .text = "",
    .data = &game_speed_spinner_data,
    .element = .GameSpeedSpinner,
};

var game_speed_spinner_data: Spinner.Data = .{
    .min = 1,
    .max = std.math.maxInt(i32),
    .value = 60,
    .editing = false,
};

pub const game_type_dropdown: Dropdown = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 40 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 40 },
    },
    .contents = GameType,
    .data = &game_type_dropdown_data,
    .element = .GameTypeDropdown,
};

var game_type_dropdown_data: Dropdown.Data = .{
    .selected = @intFromEnum(GameType.@"Static Array"),
};

pub const dynamic_array_options_box: Container = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 100 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 165 },
    },
    .title = "Options",
    .type = .GroupBox,
    .element = .Sidebar,
};

pub const dynamic_array_width_spinner: Spinner = .{
    .rect = .{
        .parent = &dynamic_array_options_box.rect,
        .x = .{ .left = 60 },
        .y = .{ .top = 15 },
        .width = .{ .relative = -80 },
        .height = .{ .amount = 20 },
    },
    .text = "Width: ",
    .data = &dynamic_array_width_spinner_data,
    .element = .DynamicArrayWidthSpinner,
};

var dynamic_array_width_spinner_data: Spinner.Data = .{
    .min = 1,
    .max = std.math.maxInt(i32),
    .value = 256,
    .editing = false,
};

pub const dynamic_array_height_spinner: Spinner = .{
    .rect = .{
        .parent = &dynamic_array_options_box.rect,
        .x = .{ .left = 60 },
        .y = .{ .top = 45 },
        .width = .{ .relative = -80 },
        .height = .{ .amount = 20 },
    },
    .text = "Height: ",
    .data = &dynamic_array_height_spinner_data,
    .element = .DynamicArrayHeightSpinner,
};

var dynamic_array_height_spinner_data: Spinner.Data = .{
    .min = 1,
    .max = std.math.maxInt(i32),
    .value = 256,
    .editing = false,
};

pub const dynamic_array_xwrap_dropdown: Dropdown = .{
    .rect = .{
        .parent = &dynamic_array_options_box.rect,
        .x = .{ .left = 60 },
        .y = .{ .top = 80 },
        .width = .{ .relative = -80 },
        .height = .{ .amount = 30 },
    },
    .contents = Wrap,
    .data = &dynamic_array_xwrap_dropdown_data,
    .element = .DynamicArrayXWrapDropdown,
};

var dynamic_array_xwrap_dropdown_data: Dropdown.Data = .{
    .selected = @intFromEnum(Wrap.Normal),
};

pub const dynamic_array_ywrap_dropdown: Dropdown = .{
    .rect = .{
        .parent = &dynamic_array_options_box.rect,
        .x = .{ .left = 60 },
        .y = .{ .top = 120 },
        .width = .{ .relative = -80 },
        .height = .{ .amount = 30 },
    },
    .contents = Wrap,
    .data = &dynamic_array_ywrap_dropdown_data,
    .element = .DynamicArrayYWrapDropdown,
};

var dynamic_array_ywrap_dropdown_data: Dropdown.Data = .{
    .selected = @intFromEnum(Wrap.Normal),
};
