const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const Vec2 = rl.Vector2;
const Rect = rl.Rectangle;

pub const sidebar_width = 250;

pub fn drawButton(b: Button, ctx: anytype) void {
    const rect = rectFromVecs(b.getPos(), b.size);

    if (rg.guiButton(rect, b.text) != 0) {
        b.func(ctx);
    }
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
    func: fn (ctx: anytype) void,

    pub fn getPos(self: Button) Vec2 {
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

pub const clear_button: Button = .{
    .container = &controls,
    .pos = Vec2.init(20, 20),
    .size = Vec2.init(controls.size.x - 40, 40),
    .text = "Clear",
    .func = struct {
        pub fn func(ctx: anytype) void {
            ctx.game.clear();
        }
    }.func,
};

pub const randomize_button: Button = .{
    .container = &controls,
    .pos = Vec2.init(20, clear_button.pos.y + 60),
    .size = Vec2.init(controls.size.x - 40, 40),
    .text = "Randomize",
    .func = struct {
        pub fn func(ctx: anytype) void {
            ctx.game.randomize(ctx.rng);
        }
    }.func,
};

pub const pause_button: Button = .{
    .container = &controls,
    .pos = Vec2.init(20, randomize_button.pos.y + 60),
    .size = Vec2.init(controls.size.x - 40, 40),
    .text = "Pause",
    .func = struct {
        pub fn func(ctx: anytype) void {
            ctx.paused.* = true;
        }
    }.func,
};

pub const unpause_button: Button = .{
    .container = pause_button.container,
    .pos = pause_button.pos,
    .size = pause_button.size,
    .text = "Unpause",
    .func = struct {
        pub fn func(ctx: anytype) void {
            ctx.paused.* = false;
        }
    }.func,
};

pub const step_button: Button = .{
    .container = &controls,
    .pos = Vec2.init(20, pause_button.pos.y + 60),
    .size = Vec2.init(controls.size.x - 40, 40),
    .text = "Step",
    .func = struct {
        pub fn func(ctx: anytype) void {
            ctx.game.next();
        }
    }.func,
};

pub const edit_mode_radio: RadioButtons = .{
    .container = null,
    .pos = Vec2.init(20, 20),
    .radio_size = Vec2.init(15, 15),
    .offset = Vec2.init(0, 20),
};
