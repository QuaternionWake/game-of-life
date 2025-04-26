const std = @import("std");
const math = std.math;
const List = std.ArrayList;
const Random = std.Random;
const Allocator = std.mem.Allocator;

const Gol = @import("../GameOfLife.zig");
const Tile = Gol.Tile;

const x_len = 256;
const y_len = 256;
const Board = [y_len][x_len]bool;

front_board: Board = undefined,
back_board: Board = undefined,
flipped: bool = false,

const Self = @This();

pub fn init(rng: Random) Self {
    var self = Self{};
    self.randomize(rng);
    return self;
}

pub fn gol(self: *Self) Gol {
    return Gol.init(
        self,
        next,
        clear,
        randomize,
        setTile,
        setTiles,
        getTiles,
    );
}

fn clear(self: *Self) void {
    @memset(std.mem.asBytes(self.getBoard()), 0);
}

fn randomize(self: *Self, rng: Random) void {
    const board = self.getBoard();
    for (board) |*row| {
        for (row) |*tile| {
            tile.* = rng.boolean();
        }
    }
}

fn setTile(self: *Self, x: isize, y: isize, tile: bool) void {
    const board = self.getBoard();
    if (x >= 0 and x < x_len and y > 0 and y < y_len) {
        board[@intCast(y)][@intCast(x)] = tile;
    }
}

fn setTiles(self: *Self, x: isize, y: isize, tiles: []Tile) void {
    const board = self.getBoard();
    for (tiles) |orig_tile| {
        const tile = .{ .x = orig_tile.x + x, .y = orig_tile.y + y };
        if (tile.x >= 0 and tile.x < x_len and tile.y > 0 and tile.y < y_len) {
            board[@intCast(tile.y)][@intCast(tile.x)] = true;
        }
    }
}

fn getTiles(self: *Self, x_start: isize, y_start: isize, x_end: isize, y_end: isize, ally: Allocator) List(Tile) {
    const board = self.getBoard();
    // no shadowning :'(
    const x_start_: usize = @intCast(@max(x_start, 0));
    const y_start_: usize = @intCast(@max(y_start, 0));
    const x_end_ = math.lossyCast(usize, @min(x_end, x_len));
    const y_end_ = math.lossyCast(usize, @min(y_end, y_len));

    var tiles = List(Tile).init(ally);
    if (y_start_ > y_end_ or x_start_ > y_end_) return tiles;
    for (y_start_..y_end_) |y| {
        for (x_start_..x_end_) |x| {
            if (board[y][x]) {
                tiles.append(.{ .x = @intCast(x), .y = @intCast(y) }) catch return tiles;
            }
        }
    }
    return tiles;
}

fn next(self: *Self) void {
    self.flipped = !self.flipped;
    const read_board = self.getInactiveBoard();
    const write_board = self.getBoard();
    for (1..y_len - 1) |y| {
        for (1..x_len - 1) |x| {
            write_board[y][x] = nextTile(read_board, x, y);
        }
    }
    for (1..x_len - 1) |x| {
        write_board[0][x] = nextTileEdgeT(read_board, x);
    }
    for (1..x_len - 1) |x| {
        write_board[y_len - 1][x] = nextTileEdgeB(read_board, x);
    }
    for (1..y_len - 1) |y| {
        write_board[y][0] = nextTileEdgeR(read_board, y);
    }
    for (1..y_len - 1) |y| {
        write_board[y][x_len - 1] = nextTileEdgeL(read_board, y);
    }
    write_board[0][0] = nextTileCornerTL(read_board);
    write_board[0][x_len - 1] = nextTileCornerTR(read_board);
    write_board[y_len - 1][0] = nextTileCornerTL(read_board);
    write_board[y_len - 1][x_len - 1] = nextTileCornerTL(read_board);
}

fn getBoard(self: *Self) *Board {
    if (self.flipped) {
        return &self.back_board;
    } else {
        return &self.front_board;
    }
}

fn getInactiveBoard(self: *Self) *Board {
    if (self.flipped) {
        return &self.front_board;
    } else {
        return &self.back_board;
    }
}

fn nextTile(board: *const Board, x: usize, y: usize) bool {
    const count =
        @as(u8, @intFromBool(board[y - 1][x - 1])) +
        @as(u8, @intFromBool(board[y - 1][x + 0])) +
        @as(u8, @intFromBool(board[y - 1][x + 1])) +
        @as(u8, @intFromBool(board[y + 0][x - 1])) +
        @as(u8, @intFromBool(board[y + 0][x + 1])) +
        @as(u8, @intFromBool(board[y + 1][x - 1])) +
        @as(u8, @intFromBool(board[y + 1][x + 0])) +
        @as(u8, @intFromBool(board[y + 1][x + 1]));

    if (board[y][x]) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}

fn nextTileEdgeT(board: *const Board, x: usize) bool {
    const count =
        @as(u8, @intFromBool(board[0][x - 1])) +
        @as(u8, @intFromBool(board[0][x + 1])) +
        @as(u8, @intFromBool(board[1][x - 1])) +
        @as(u8, @intFromBool(board[1][x + 0])) +
        @as(u8, @intFromBool(board[1][x + 1]));

    if (board[0][x]) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}

fn nextTileEdgeB(board: *const Board, x: usize) bool {
    const count =
        @as(u8, @intFromBool(board[y_len - 2][x - 1])) +
        @as(u8, @intFromBool(board[y_len - 2][x + 0])) +
        @as(u8, @intFromBool(board[y_len - 2][x + 1])) +
        @as(u8, @intFromBool(board[y_len - 1][x - 1])) +
        @as(u8, @intFromBool(board[y_len - 1][x + 1]));

    if (board[0][x]) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}

fn nextTileEdgeR(board: *const Board, y: usize) bool {
    const count =
        @as(u8, @intFromBool(board[y - 1][0])) +
        @as(u8, @intFromBool(board[y - 1][1])) +
        @as(u8, @intFromBool(board[y + 0][1])) +
        @as(u8, @intFromBool(board[y + 1][0])) +
        @as(u8, @intFromBool(board[y + 1][1]));

    if (board[y][0]) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}

fn nextTileEdgeL(board: *const Board, y: usize) bool {
    const count =
        @as(u8, @intFromBool(board[y - 1][x_len - 2])) +
        @as(u8, @intFromBool(board[y - 1][x_len - 1])) +
        @as(u8, @intFromBool(board[y + 0][x_len - 2])) +
        @as(u8, @intFromBool(board[y + 1][x_len - 2])) +
        @as(u8, @intFromBool(board[y + 1][x_len - 1]));

    if (board[y][x_len - 1]) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}

fn nextTileCornerTL(board: *const Board) bool {
    const count =
        @as(u8, @intFromBool(board[0][1])) +
        @as(u8, @intFromBool(board[1][0])) +
        @as(u8, @intFromBool(board[1][1]));

    if (board[0][0]) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}

fn nextTileCornerTR(board: *const Board) bool {
    const count =
        @as(u8, @intFromBool(board[0][x_len - 2])) +
        @as(u8, @intFromBool(board[1][x_len - 2])) +
        @as(u8, @intFromBool(board[1][x_len - 1]));

    if (board[0][x_len - 1]) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}

fn nextTileCornerBL(board: *const Board) bool {
    const count =
        @as(u8, @intFromBool(board[y_len - 2][0])) +
        @as(u8, @intFromBool(board[y_len - 2][1])) +
        @as(u8, @intFromBool(board[y_len - 1][1]));

    if (board[y_len - 1][0]) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}

fn nextTileCornerBR(board: *const Board) bool {
    const count =
        @as(u8, @intFromBool(board[y_len - 2][x_len - 2])) +
        @as(u8, @intFromBool(board[y_len - 2][x_len - 1])) +
        @as(u8, @intFromBool(board[y_len - 1][x_len - 1]));

    if (board[y_len - 1][x_len - 1]) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}
