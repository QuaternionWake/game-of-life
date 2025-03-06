const rl = @import("raylib");
const rg = @import("raygui");

const Vec2 = rl.Vector2;
const Rect = rl.Rectangle;

pub const sidebar_width = 250;

pub fn drawButton(b: Button, ctx: anytype) void {
    const rect = if (b.container) |container| rect: {
        const pos = container.getPos().add(b.pos);
        break :rect Rect.init(pos.x, pos.y, b.size.x, b.size.y);
    } else rect: {
        break :rect Rect.init(b.pos.x, b.pos.y, b.size.x, b.size.y);
    };

    if (rg.guiButton(rect, b.text) != 0) {
        b.func(ctx);
    }
}

pub fn drawContainer(c: Container) void {
    const rect = if (c.container) |container| rect: {
        const pos = container.getPos().add(c.pos);
        break :rect Rect.init(pos.x, pos.y, c.size.x, c.size.y);
    } else rect: {
        break :rect Rect.init(c.pos.x, c.pos.y, c.size.x, c.size.y);
    };

    switch (c.type) {
        .Panel => {
            _ = rg.guiPanel(rect, c.title);
        },
        .GroupBox => {
            _ = rg.guiGroupBox(rect, c.title);
        },
    }
}

pub fn updateSidebar(screen_width: i32, screen_height: i32) void {
    sidebar.pos.x = @floatFromInt(screen_width - sidebar_width);
    sidebar.size.y = @floatFromInt(screen_height);
}

const Container = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    title: [*:0]const u8,
    type: enum { Panel, GroupBox },

    pub fn getRect(self: Container) Rect {
        return Rect.init(self.pos.x, self.pos.y, self.size.x, self.size.y);
    }

    pub fn getPos(self: Container) Vec2 {
        if (self.container) |c| {
            return c.pos.add(self.pos);
        } else {
            return self.pos;
        }
    }
};

const Button = struct {
    container: ?*const Container,
    pos: Vec2,
    size: Vec2,
    text: [*:0]const u8,
    func: fn (ctx: anytype) void,
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
