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

    switch (sidebar_tab_buttons.data.selected) {
        .Settings => _ = grabElementGroup(settings_elements),
        .Patterns => _ = grabElementGroup(pattern_list_elements),
        .GameTypes => if (!grabElementGroup(game_type_elements)) {
            switch (game_type_dropdown.data.selected) {
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

fn nullOrNew(old: anytype, new: anytype) ?@TypeOf(new) {
    return if (old == new) null else new;
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

    pub fn draw(self: List, items: [][*:0]const u8) ??usize {
        var active_inner: i32 = if (self.data.active) |a| @intCast(a) else -1;
        var _focused: i32 = -1;

        const old_active = self.data.active;

        if (isHolding(self)) {
            _ = rg.listViewEx(self.getRect(), items, &self.data.scroll, &active_inner, &_focused);

            self.data.active = if (active_inner != -1) @intCast(active_inner) else null;
        } else if (canGrab(self)) {
            _ = rg.listViewEx(self.getRect(), items, &self.data.scroll, &active_inner, &_focused);
        } else {
            rg.lock();
            _ = rg.listViewEx(self.getRect(), items, &self.data.scroll, &active_inner, &_focused);
            rg.unlock();
        }
        return nullOrNew(old_active, self.data.active);
    }

    const Data = struct {
        scroll: i32 = 0,
        active: ?usize = null,
    };
};

fn TabbedList(Tabs: type) type {
    return struct {
        rect: Rect,
        tab_height: f32,
        tab_edge_padding: f32,
        tab_inner_padding: f32,
        data: *Data,
        element: GuiElement,

        const Self = @This();

        pub fn getRect(self: Self) RlRect {
            return self.rect.rlRect();
        }

        pub fn containsPoint(self: Self, point: Vec2) bool {
            return rl.checkCollisionPointRec(point, self.getRect());
        }

        pub fn getTabButtons(self: *const Self, data_buf: *TabButtons(Tabs).Data) TabButtons(Tabs) {
            data_buf.* = self.data.getTabButtonsData();
            return .{
                .rect = .{
                    .parent = &self.rect,
                    .x = .{ .left = 0 },
                    .y = .{ .top = 0 },
                    .width = .{ .relative = 0 },
                    .height = .{ .amount = self.tab_height },
                },
                .direction = .Horizontal,
                .edge_padding = self.tab_edge_padding,
                .inner_padding = self.tab_inner_padding,
                .data = data_buf,
                .element = self.element,
            };
        }

        pub fn getList(self: *const Self, data_buf: *List.Data) List {
            data_buf.* = self.data.getListData();
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

        pub fn draw(self: Self, items: EnumArray(Tabs, [][*:0]const u8)) ?Index {
            var tabs_data_buf: TabButtons(Tabs).Data = undefined;
            if (self.getTabButtons(&tabs_data_buf).draw()) |tab| {
                self.data.open_tab = tab;
            }

            var list_data_buf: List.Data = undefined;
            var result: ?Index = null;
            if (self.getList(&list_data_buf).draw(items.get(self.data.open_tab))) |active| {
                self.data.selected_tab = self.data.open_tab;
                self.data.active = active;
                result = .{ .tab = self.data.selected_tab, .index = active };
            }
            self.data.scroll.getPtr(self.data.open_tab).* = list_data_buf.scroll;
            return result;
        }

        const Index = struct {
            tab: Tabs,
            index: ?usize,
        };

        const Data = struct {
            scroll: EnumArray(Tabs, i32) = .initFill(0),
            active: ?usize = null,
            selected_tab: Tabs = @enumFromInt(0),
            open_tab: Tabs = @enumFromInt(0),

            pub fn getTabButtonsData(self: Data) TabButtons(Tabs).Data {
                return .{
                    .selected = self.open_tab,
                };
            }

            pub fn getListData(self: Data) List.Data {
                return .{
                    .scroll = self.scroll.get(self.open_tab),
                    .active = if (self.open_tab == self.selected_tab) self.active else null,
                };
            }
        };
    };
}

fn TabButtons(Tabs: type) type {
    return struct {
        rect: Rect,
        direction: enum { Vertical, Horizontal },
        edge_padding: f32,
        inner_padding: f32,
        data: *Data,
        element: GuiElement,

        const Self = @This();

        pub fn getRect(self: Self) RlRect {
            return self.rect.rlRect();
        }

        pub fn containsPoint(self: Self, point: Vec2) bool {
            const len = std.meta.fields(Tabs).len;
            var rect, const offset = self.getRectAndOffset();

            for (0..len) |_| {
                if (rl.checkCollisionPointRec(point, rect)) {
                    return true;
                }
                rect.x += offset.x;
                rect.y += offset.y;
            }

            return false;
        }

        pub fn draw(self: Self) ?Tabs {
            var rect, const offset = self.getRectAndOffset();

            const fields = std.meta.fields(Tabs);

            var result: ?Tabs = null;
            inline for (fields) |field| {
                if ((@as(Tabs, @enumFromInt(field.value))) == self.data.selected) {
                    rg.setState(@intFromEnum(rg.State.pressed));
                }
                defer if (@as(Tabs, @enumFromInt(field.value)) == self.data.selected) {
                    rg.setState(@intFromEnum(rg.State.normal));
                };
                if (isHolding(self)) {
                    if (rg.button(rect, field.name)) {
                        self.data.selected = @enumFromInt(field.value);
                        result = @enumFromInt(field.value);
                    }
                } else if (canGrab(self)) {
                    _ = rg.button(rect, field.name);
                } else {
                    rg.lock();
                    _ = rg.button(rect, field.name);
                    rg.unlock();
                }

                rect.x += offset.x;
                rect.y += offset.y;
            }
            return result;
        }

        fn getRectAndOffset(self: Self) struct { RlRect, Vec2 } {
            const rect = self.getRect();

            const fields = std.meta.fields(Tabs);
            const len = fields.len;
            const btn_rect = blk: {
                const width = switch (self.direction) {
                    .Horizontal => (rect.width - 2 * self.edge_padding + self.inner_padding) / len - self.inner_padding,
                    .Vertical => rect.width,
                };
                const height = switch (self.direction) {
                    .Vertical => (rect.height - 2 * self.edge_padding + self.inner_padding) / len - self.inner_padding,
                    .Horizontal => rect.height,
                };
                const x = switch (self.direction) {
                    .Horizontal => rect.x + self.edge_padding,
                    .Vertical => rect.x,
                };
                const y = switch (self.direction) {
                    .Vertical => rect.y + self.edge_padding,
                    .Horizontal => rect.y,
                };
                break :blk RlRect.init(x, y, width, height);
            };
            const rect_offset = switch (self.direction) {
                .Horizontal => Vec2.init(btn_rect.width + self.inner_padding, 0),
                .Vertical => Vec2.init(0, btn_rect.height + self.inner_padding),
            };
            return .{ btn_rect, rect_offset };
        }

        const Data = struct {
            selected: Tabs = @enumFromInt(0),
        };
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

    /// Returns value when it has changed
    pub fn draw(self: Self) ?f32 {
        const old_value = self.data.value;
        if (canGrab(self)) {
            _ = rg.slider(self.getRect(), self.text_left, self.text_right, &self.data.value, self.data.min, self.data.max);
        } else {
            rg.lock();
            _ = rg.slider(self.getRect(), self.text_left, self.text_right, &self.data.value, self.data.min, self.data.max);
            rg.unlock();
        }
        return nullOrNew(old_value, self.data.value);
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

    /// If `return_on_change` is true - retruns value whenever it changes.
    /// Otherwise, returns value when editing is finished.
    pub fn draw(self: Self, return_on_change: bool) ?i32 {
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
        return if (return_on_change)
            nullOrNew(old_value, self.data.value)
        else if (stopped_editing)
            self.data.value
        else
            null;
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

        /// Returns value when it has changed
        pub fn draw(self: Self) ?Contents {
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

            var selected_idx: i32 = @intFromEnum(self.data.selected);

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

            self.data.selected = @enumFromInt(selected_idx);
            return nullOrNew(@as(Contents, @enumFromInt(selected_idx)), self.data.selected);
        }

        const Data = struct {
            selected: Contents = @enumFromInt(0),
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

    /// Returns value when editing stops.
    pub fn draw(self: Self) ?[:0]u8 {
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
        return if (previous_editing and !self.data.editing)
            self.data.text_buffer
        else
            null;
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
    .tab_edge_padding = 5,
    .tab_inner_padding = 3,
    .data = &pattern_list_data,
    .element = .PatternList,
};

var pattern_list_data: TabbedList(Category).Data = .{};

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
        .height = .{ .amount = 100 },
    },
    .direction = .Vertical,
    .edge_padding = 0,
    .inner_padding = 5,
    .data = &sidebar_tab_buttons_data,
    .element = .SidebarTabButtons,
};

var sidebar_tab_buttons_data: TabButtons(SidebarTabs).Data = .{};

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

var game_type_dropdown_data: Dropdown(GameType).Data = .{};

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
    .selected = Wrap.Normal,
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
    .selected = Wrap.Normal,
};
