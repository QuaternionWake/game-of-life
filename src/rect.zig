const rl = @import("raylib");

const RlRect = rl.Rectangle;

const Rect = @This();

parent: ?*const Rect,

x: HorizontalPos,
y: VerticalPos,

width: Size,
height: Size,

pub fn rlRect(self: Rect) RlRect {
    const parent = if (self.parent) |parent| parent.rlRect() else screenRect();

    const width = switch (self.width) {
        .amount => |val| val,
        .ratio => |val| parent.width * val,
        .relative => |val| parent.width + val,
    };

    const height = switch (self.height) {
        .amount => |val| val,
        .ratio => |val| parent.height * val,
        .relative => |val| parent.height + val,
    };

    const x = switch (self.x) {
        .left => |val| parent.x + val,
        .middle => |val| parent.x + parent.width / 2 + val - width / 2,
        .right => |val| parent.x + parent.width + val - width,
    };
    const y = switch (self.y) {
        .top => |val| parent.y + val,
        .middle => |val| parent.y + parent.height / 2 + val - height / 2,
        .bottom => |val| parent.y + parent.height + val - height,
    };
    return RlRect.init(x, y, width, height);
}

fn screenRect() RlRect {
    return RlRect.init(0, 0, @floatFromInt(rl.getScreenWidth()), @floatFromInt(rl.getScreenHeight()));
}

const VerticalPos = union(enum) {
    top: f32,
    middle: f32,
    bottom: f32,
};
const HorizontalPos = union(enum) {
    left: f32,
    middle: f32,
    right: f32,
};

const Size = union(enum) {
    amount: f32,
    ratio: f32,
    relative: f32,
};
