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

const Container = struct {
    rect: Rect,
    title: [:0]const u8,
    type: enum { Panel, GroupBox },
    element: GuiElement,

    const Self = @This();

    pub fn getRect(self: Self) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Self, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }

    pub fn draw(self: Self) void {
        switch (self.type) {
            .Panel => {
                _ = rg.panel(self.getRect(), self.title);
            },
            .GroupBox => {
                _ = rg.groupBox(self.getRect(), self.title);
            },
        }
    }
};

const Button = struct {
    rect: Rect,
    text: [:0]const u8,
    element: GuiElement,

    const Self = @This();

    pub fn getRect(self: Self) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Self, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }

    /// Returns true when clicked
    pub fn draw(self: Self) bool {
        if (isHolding(self)) {
            return rg.button(self.getRect(), self.text);
        } else if (canGrab(self)) {
            _ = rg.button(self.getRect(), self.text);
            return false;
        } else {
            rg.lock();
            _ = rg.button(self.getRect(), self.text);
            rg.unlock();
            return false;
        }
    }
};

const List = struct {
    rect: Rect,
    data: *Data,
    element: GuiElement,

    const Self = @This();

    pub fn getRect(self: Self) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Self, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }

    pub fn draw(self: List, items: [][*:0]const u8) void {
        var active_inner: i32 = if (self.data.active) |a| @intCast(a) else -1;
        var focused_inner: i32 = if (self.data.focused) |f| @intCast(f) else -1;

        if (isHolding(self)) {
            _ = rg.listViewEx(self.getRect(), items, &self.data.scroll, &active_inner, &focused_inner);

            self.data.active = if (active_inner != -1) @intCast(active_inner) else null;
            self.data.focused = if (focused_inner != -1) @intCast(focused_inner) else null;
        } else if (canGrab(self)) {
            _ = rg.listViewEx(self.getRect(), items, &self.data.scroll, &active_inner, &focused_inner);
        } else {
            rg.lock();
            _ = rg.listViewEx(self.getRect(), items, &self.data.scroll, &active_inner, &focused_inner);
            rg.unlock();
        }
    }

    const Data = struct {
        scroll: i32 = 0,
        active: ?usize = null,
        focused: ?usize = null,
    };
};

fn TabbedList(Tabs: type) type {
    return struct {
        rect: Rect,
        tab_height: f32,
        data: *Data,
        element: GuiElement,

        const Self = @This();

        pub fn getRect(self: Self) RlRect {
            return self.rect.rlRect();
        }

        pub fn containsPoint(self: Self, point: Vec2) bool {
            return rl.checkCollisionPointRec(point, self.getRect());
        }

        pub fn getTab(self: Self) Tabs {
            return @enumFromInt(self.data.tab);
        }

        pub fn getTabButtons(self: *const Self) TabButtons(Tabs) {
            const tab_count = @typeInfo(Tabs).@"enum".fields.len;
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
                .element = self.element,
            };
        }

        pub fn getList(self: *const Self, data_buf: *List.Data) List {
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

        pub fn draw(self: Self, items: EnumArray(Tabs, [][*:0]const u8)) void {
            if (self.getTabButtons().draw()) |tab| {
                self.data.tab = @intFromEnum(tab);
            }

            var list_data_buf: List.Data = undefined;
            self.getList(&list_data_buf).draw(items.get(self.getTab()));
            self.data.scroll[self.data.tab] = list_data_buf.scroll;
            self.data.active = list_data_buf.active;
            self.data.focused = list_data_buf.focused;
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
}

fn TabButtons(Tabs: type) type {
    return struct {
        rect: Rect,
        offset: Vec2,
        element: GuiElement,

        const Self = @This();

        pub fn getRect(self: Self) RlRect {
            return self.rect.rlRect();
        }

        pub fn containsPoint(self: Self, point: Vec2) bool {
            const len = std.meta.fields(Tabs).len;
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

        pub fn draw(self: Self) ?Tabs {
            var rect = self.getRect();

            const fields = std.meta.fields(Tabs);

            var result: ?Tabs = null;
            inline for (fields) |field| {
                if (isHolding(self)) {
                    if (rg.button(rect, field.name)) {
                        result = @enumFromInt(field.value);
                    }
                } else if (canGrab(self)) {
                    _ = rg.button(rect, field.name);
                } else {
                    rg.lock();
                    _ = rg.button(rect, field.name);
                    rg.unlock();
                }

                rect.x += self.offset.x;
                rect.y += self.offset.y;
            }
            return result;
        }
    };
}

const Slider = struct {
    rect: Rect,
    text_left: [:0]const u8,
    text_right: [:0]const u8,
    data: *Data,
    element: GuiElement,

    const Self = @This();

    pub fn getRect(self: Self) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Self, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }

    /// Returns true when value has changed
    pub fn draw(self: Self) bool {
        const old_value = self.data.value;
        if (canGrab(self)) {
            _ = rg.slider(self.getRect(), self.text_left, self.text_right, &self.data.value, self.data.min, self.data.max);
        } else {
            rg.lock();
            _ = rg.slider(self.getRect(), self.text_left, self.text_right, &self.data.value, self.data.min, self.data.max);
            rg.unlock();
        }
        return old_value != self.data.value;
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

    const Self = @This();

    pub fn getRect(self: Self) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Self, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }

    /// If `return_on_change` is true - retruns true whenever value changes.
    /// Otherwise, returns true when editing is finished.
    pub fn draw(self: Self, return_on_change: bool) bool {
        const old_value = self.data.value;
        var stopped_editing = false;
        if (isHolding(self)) {
            if (rg.spinner(self.getRect(), self.text, &self.data.value, self.data.min, self.data.max, self.data.editing) != 0) {
                self.data.editing = !self.data.editing;
                stopped_editing = !self.data.editing;
            }
        } else if (canGrab(self)) {
            // giving it val for min and max both prevents it form editing the value and from drawing
            // the wrong, edited value for one frame
            if (rg.spinner(self.getRect(), self.text, &self.data.value, self.data.value, self.data.value, self.data.editing) != 0) {
                self.data.editing = !self.data.editing;
                stopped_editing = !self.data.editing;
            }
        } else {
            rg.lock();
            _ = rg.spinner(self.getRect(), self.text, &self.data.value, self.data.min, self.data.max, self.data.editing);
            rg.unlock();
        }
        if (return_on_change) {
            return old_value != self.data.value;
        } else {
            return stopped_editing;
        }
    }

    const Data = struct {
        min: i32,
        max: i32,
        value: i32,
        editing: bool = false,
    };
};

fn Dropdown(Contents: type) type {
    return struct {
        rect: Rect,
        data: *Data,
        element: GuiElement,

        const Self = @This();

        pub fn getRect(self: Self) RlRect {
            return self.rect.rlRect();
        }

        pub fn containsPoint(self: Self, point: Vec2) bool {
            var rect = self.getRect();
            if (self.data.editing) {
                rect.height += @floatFromInt(rg.getStyle(.dropdownbox, .{ .default = .text_spacing }));
                const len = std.meta.fields(Contents).len;
                rect.height *= len + 1;
            }

            return rl.checkCollisionPointRec(point, rect);
        }

        pub fn getSelected(self: Self) Contents {
            return @enumFromInt(self.data.selected);
        }

        /// Returns true when value has changed
        pub fn draw(self: Self) bool {
            const fields = std.meta.fields(Contents);
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

            var selected_idx: i32 = @intCast(self.data.selected);

            if (isHolding(self)) {
                if (rg.dropdownBox(self.getRect(), &field_names, &selected_idx, self.data.editing) != 0) {
                    self.data.editing = !self.data.editing;
                }
            } else if (canGrab(self)) {
                if (rg.dropdownBox(self.getRect(), &field_names, &selected_idx, self.data.editing) != 0) {
                    self.data.editing = !self.data.editing;
                }
            } else {
                rg.lock();
                _ = rg.dropdownBox(self.getRect(), &field_names, &selected_idx, self.data.editing);
                rg.unlock();
            }

            if (selected_idx != self.data.selected) {
                self.data.selected = @intCast(selected_idx);
                return true;
            }
            return false;
        }

        const Data = struct {
            selected: usize = 0,
            editing: bool = false,
        };
    };
}

const TextInput = struct {
    rect: Rect,
    data: *Data,
    element: GuiElement,

    const Self = @This();

    pub fn getRect(self: Self) RlRect {
        return self.rect.rlRect();
    }

    pub fn containsPoint(self: Self, point: Vec2) bool {
        return rl.checkCollisionPointRec(point, self.getRect());
    }

    /// Returns true when editing stops.
    pub fn draw(self: Self) bool {
        const previous_editing = self.data.editing;
        if (self.data.editing or canGrab(self)) {
            if (rg.textBox(self.getRect(), self.data.text_buffer, @intCast(self.data.text_buffer.len - 1), self.data.editing)) {
                self.data.editing = !self.data.editing;
            }
        } else {
            rg.lock();
            _ = rg.textBox(self.getRect(), self.data.text_buffer, @intCast(self.data.text_buffer.len - 1), self.data.editing);
            rg.unlock();
        }
        return previous_editing and !self.data.editing;
    }

    const Data = struct {
        text_buffer: [:0]u8,
        editing: bool = false,
    };
};

// dummy struct for consistency
const Grid = struct {
    element: GuiElement = .Grid,

    const Self = @This();

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

pub const pattern_list: TabbedList(Category) = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 40 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 250 },
    },
    .tab_height = 20,
    .data = &pattern_list_data,
    .element = .PatternList,
};

var pattern_list_data: TabbedList(Category).Data = .{
    .scroll = &pattern_list_scroll,
};

var pattern_list_scroll: [@typeInfo(Category).@"enum".fields.len]i32 = @splat(0);

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

pub const load_pattern_extension_dropdown: Dropdown(LoadableFormats) = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .right = -65 },
        .y = .{ .top = 340 },
        .width = .{ .amount = 60 },
        .height = .{ .amount = 25 },
    },
    .data = &load_pattern_extension_dropdown_data,
    .element = .LoadPatternExtension,
};

var load_pattern_extension_dropdown_data: Dropdown(LoadableFormats).Data = .{};

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

pub const sidebar_tab_buttons: TabButtons(SidebarTabs) = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .left = -30 },
        .y = .{ .top = 30 },
        .width = .{ .amount = 32 },
        .height = .{ .amount = 30 },
    },
    .offset = Vec2.init(0, 35),
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

pub const game_type_dropdown: Dropdown(GameType) = .{
    .rect = .{
        .parent = &sidebar.rect,
        .x = .{ .middle = 0 },
        .y = .{ .top = 40 },
        .width = .{ .relative = -40 },
        .height = .{ .amount = 40 },
    },
    .data = &game_type_dropdown_data,
    .element = .GameTypeDropdown,
};

var game_type_dropdown_data: Dropdown(GameType).Data = .{
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

pub const dynamic_array_xwrap_dropdown: Dropdown(Wrap) = .{
    .rect = .{
        .parent = &dynamic_array_options_box.rect,
        .x = .{ .left = 60 },
        .y = .{ .top = 80 },
        .width = .{ .relative = -80 },
        .height = .{ .amount = 30 },
    },
    .data = &dynamic_array_xwrap_dropdown_data,
    .element = .DynamicArrayXWrapDropdown,
};

var dynamic_array_xwrap_dropdown_data: Dropdown(Wrap).Data = .{
    .selected = @intFromEnum(Wrap.Normal),
};

pub const dynamic_array_ywrap_dropdown: Dropdown(Wrap) = .{
    .rect = .{
        .parent = &dynamic_array_options_box.rect,
        .x = .{ .left = 60 },
        .y = .{ .top = 120 },
        .width = .{ .relative = -80 },
        .height = .{ .amount = 30 },
    },
    .data = &dynamic_array_ywrap_dropdown_data,
    .element = .DynamicArrayYWrapDropdown,
};

var dynamic_array_ywrap_dropdown_data: Dropdown(Wrap).Data = .{
    .selected = @intFromEnum(Wrap.Normal),
};
