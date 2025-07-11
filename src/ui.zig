const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");
const Vec2 = rl.Vector2;
const RlRect = rl.Rectangle;

const Rect = @import("rect.zig");

const GameType = @import("main.zig").GameType;
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
    const mouse_pos = rl.getMousePosition();
    inline for (top_level_elements) |e| {
        if (e.containsPoint(mouse_pos)) {
            hovered_element = e.element;
            break;
        }
    }

    switch (sidebar_tab) {
        .Settings => inline for (settings_elements) |e| {
            if (e.containsPoint(mouse_pos)) {
                hovered_element = e.element;
                break;
            }
        },
        .Patterns => inline for (pattern_list_elements) |e| {
            if (e.containsPoint(mouse_pos)) {
                hovered_element = e.element;
                break;
            }
        },
        .GameTypes => inline for (game_type_elements) |e| {
            if (e.containsPoint(mouse_pos)) {
                hovered_element = e.element;
                break;
            }
        } else {
            switch (game_type_dropdown.getSelected()) {
                .@"Static Array" => inline for (static_game_elements) |e2| {
                    if (e2.containsPoint(mouse_pos)) {
                        hovered_element = e2.element;
                        break;
                    }
                },
                .@"Dynamic Array" => inline for (dynamic_game_elemnts) |e2| {
                    if (e2.containsPoint(mouse_pos)) {
                        hovered_element = e2.element;
                        break;
                    }
                },
                .Hashset => inline for (hashset_game_elements) |e2| {
                    if (e2.containsPoint(mouse_pos)) {
                        hovered_element = e2.element;
                        break;
                    }
                },
                .@"Hashset (faster (sometimes))" => inline for (hashfast_game_elements) |e2| {
                    if (e2.containsPoint(mouse_pos)) {
                        hovered_element = e2.element;
                        break;
                    }
                },
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

pub fn canGrab(e: anytype) bool {
    return held_element == e.element or (held_element == null and hovered_element == e.element);
}

/// Returns true when clicked
pub fn drawButton(b: Button) bool {
    if (b.element == previous_held_element) {
        return rg.button(b.getRect(), b.text);
    } else if (previous_held_element == null) {
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

pub fn drawTabButtons(tb: TabButtons) void {
    var rect = tb.getRect();

    const fields = std.meta.fields(tb.tabs);

    inline for (fields) |field| {
        if (@as(tb.tabs, @enumFromInt(field.value)).getGuiElement() == previous_held_element) {
            if (rg.button(rect, field.name)) {
                sidebar_tab = @enumFromInt(field.value);
            }
        } else if (previous_held_element == null) {
            _ = rg.button(rect, field.name);
        } else {
            rg.lock();
            _ = rg.button(rect, field.name);
            rg.unlock();
        }

        rect.x += tb.offset.x;
        rect.y += tb.offset.y;
    }
}

pub fn drawListView(list: List, items: [][*:0]const u8) void {
    var active_inner: i32 = if (list.data.active) |a| @intCast(a) else -1;
    var focused_inner: i32 = if (list.data.focused) |f| @intCast(f) else -1;

    if (list.element == previous_held_element or previous_held_element == null) {
        _ = rg.listViewEx(list.getRect(), items, &list.data.scroll, &active_inner, &focused_inner);

        list.data.active = if (active_inner != -1) @intCast(active_inner) else null;
        list.data.focused = if (focused_inner != -1) @intCast(focused_inner) else null;
    } else {
        rg.lock();
        _ = rg.listViewEx(list.getRect(), items, &list.data.scroll, &active_inner, &focused_inner);
        rg.unlock();
    }
}

/// Returns true when editing stops.
pub fn drawTextInput(ti: TextInput) bool {
    const previous_editing = ti.data.editing;
    if (ti.element == previous_held_element or previous_held_element == null) {
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
    if (s.element == previous_held_element or previous_held_element == null) {
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
pub fn drawSpinner(sb: Spinner, return_on_change: bool) bool {
    const old_value = sb.data.value;
    var stopped_editing = false;
    if (sb.element == previous_held_element) {
        if (rg.spinner(sb.getRect(), sb.text, &sb.data.value, sb.data.min, sb.data.max, sb.data.editing) != 0) {
            sb.data.editing = !sb.data.editing;
            stopped_editing = !sb.data.editing;
        }
    } else if (previous_held_element == null) {
        // giving it val for min and max both prevents it form editing the value and from drawing
        // the wrong, edited value for one frame
        if (rg.spinner(sb.getRect(), sb.text, &sb.data.value, sb.data.value, sb.data.value, sb.data.editing) != 0) {
            sb.data.editing = !sb.data.editing;
            stopped_editing = !sb.data.editing;
        }
    } else {
        rg.lock();
        _ = rg.spinner(sb.getRect(), sb.text, &sb.data.value, sb.data.min, sb.data.max, sb.data.editing);
        rg.unlock();
    }
    if (return_on_change) {
        return old_value != sb.data.value;
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

    if (d.element == previous_held_element) {
        if (rg.dropdownBox(d.getRect(), &field_names, &selected_idx, d.data.editing) != 0) {
            d.data.editing = !d.data.editing;
        }
    } else if (previous_held_element == null) {
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
    data: *ListData,
    element: GuiElement,

    pub fn getRect(self: List) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: List, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }
};

const ListData = struct {
    scroll: i32 = 0,
    active: ?usize = null,
    focused: ?usize = null,
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
    data: *SliderData,
    element: GuiElement,

    pub fn getRect(self: Slider) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Slider, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }
};

const SliderData = struct {
    min: f32,
    max: f32,
    value: f32,
};

const Spinner = struct {
    rect: Rect,
    text: [:0]const u8,
    data: *SpinnerData,
    element: GuiElement,

    pub fn getRect(self: Spinner) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Spinner, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }
};

const SpinnerData = struct {
    min: i32,
    max: i32,
    value: i32,
    editing: bool,
};

const Dropdown = struct {
    rect: Rect,
    contents: type,
    data: *DropdownData,
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
};

const DropdownData = struct {
    selected: usize = 0,
    editing: bool = false,
};

const TextInput = struct {
    rect: Rect,
    data: *TextInputData,
    element: GuiElement,

    pub fn getRect(self: TextInput) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: TextInput, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }
};

const TextInputData = struct {
    text_buffer: [:0]u8,
    editing: bool,
};

pub const SidebarTabs = enum {
    Settings,
    Patterns,
    GameTypes,
    pub fn getGuiElement(_: SidebarTabs) GuiElement {
        return .SidebarTabButtons;
    }
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

pub const pattern_list: List = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 40 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 260 },
    },
    .data = &pattern_list_data,
    .element = .PatternList,
};

var pattern_list_data: ListData = .{};

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

var pattern_name_input_data: TextInputData = .{
    .text_buffer = &pattern_name_buf,
    .editing = false,
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

var pattern_load_path_input_data: TextInputData = .{
    .text_buffer = &pattern_load_path_buf,
    .editing = false,
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

var load_pattern_extension_dropdown_data: DropdownData = .{};

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

var game_speed_slider_data: SliderData = .{
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

var game_speed_spinner_data: SpinnerData = .{
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

var game_type_dropdown_data: DropdownData = .{
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

var dynamic_array_width_spinner_data: SpinnerData = .{
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

var dynamic_array_height_spinner_data: SpinnerData = .{
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

var dynamic_array_xwrap_dropdown_data: DropdownData = .{
    .selected = @intFromEnum(Wrap.Normal),
    .editing = false,
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

var dynamic_array_ywrap_dropdown_data: DropdownData = .{
    .selected = @intFromEnum(Wrap.Normal),
    .editing = false,
};
