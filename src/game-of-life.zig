const std = @import("std");
const Random = std.Random;

const Board = [256][256]bool;

front_board: Board = undefined,
back_board: Board = undefined,
flipped: bool = false,

const Self = @This();

pub fn init(rng: Random) Self {
    var self = Self{};
    const board = self.getBoard();
    for (board) |*row| {
        for (row) |*tile| {
            tile.* = rng.boolean();
        }
    }
    return self;
}

pub fn getBoard(self: *Self) *Board {
    if (self.flipped) {
        return &self.back_board;
    } else {
        return &self.front_board;
    }
}
