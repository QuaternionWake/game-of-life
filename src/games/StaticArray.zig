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
    if (x >= 0 and x < x_len and y >= 0 and y < y_len) {
        board[@intCast(y)][@intCast(x)] = tile;
    }
}

fn setTiles(self: *Self, x: isize, y: isize, tiles: []Tile) void {
    const board = self.getBoard();
    for (tiles) |orig_tile| {
        const tile = .{ .x = orig_tile.x + x, .y = orig_tile.y + y };
        if (tile.x >= 0 and tile.x < x_len and tile.y >= 0 and tile.y < y_len) {
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
    if (y_start_ > y_end_ or x_start_ > x_end_) return tiles;
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
            write_board[y][x] = nextTile(read_board, .{ .center = .{ .x = x, .y = y } }, .center);
        }
    }
    for (1..x_len - 1) |x| {
        write_board[0][x] = nextTile(read_board, .{ .top = .{ .x = x } }, .top);
    }
    for (1..x_len - 1) |x| {
        write_board[y_len - 1][x] = nextTile(read_board, .{ .bottom = .{ .x = x } }, .bottom);
    }
    for (1..y_len - 1) |y| {
        write_board[y][0] = nextTile(read_board, .{ .left = .{ .y = y } }, .left);
    }
    for (1..y_len - 1) |y| {
        write_board[y][x_len - 1] = nextTile(read_board, .{ .right = .{ .y = y } }, .right);
    }
    write_board[0][0] = nextTile(read_board, .{ .top_left = {} }, .top_left);
    write_board[0][x_len - 1] = nextTile(read_board, .{ .top_right = {} }, .top_right);
    write_board[y_len - 1][0] = nextTile(read_board, .{ .bottom_left = {} }, .bottom_left);
    write_board[y_len - 1][x_len - 1] = nextTile(read_board, .{ .bottom_right = {} }, .bottom_right);
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

fn nextTile(board: *const Board, tile: TileValue, comptime tile_type: TileType) bool {
    const x, const y = tile.getCoords(tile_type);
    const count =
        // Edges
        (if (comptime tile_type.hasTop()) @as(u8, @intFromBool(board[y - 1][x])) else 0) +
        (if (comptime tile_type.hasBottom()) @as(u8, @intFromBool(board[y + 1][x])) else 0) +
        (if (comptime tile_type.hasLeft()) @as(u8, @intFromBool(board[y][x - 1])) else 0) +
        (if (comptime tile_type.hasRight()) @as(u8, @intFromBool(board[y][x + 1])) else 0) +

        // Corners
        (if (comptime tile_type.hasTopLeft()) @as(u8, @intFromBool(board[y - 1][x - 1])) else 0) +
        (if (comptime tile_type.hasTopRight()) @as(u8, @intFromBool(board[y - 1][x + 1])) else 0) +
        (if (comptime tile_type.hasBottomLeft()) @as(u8, @intFromBool(board[y + 1][x - 1])) else 0) +
        (if (comptime tile_type.hasBottomRight()) @as(u8, @intFromBool(board[y + 1][x + 1])) else 0);

    if (board[y][x]) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}

const TileValue = union {
    center: struct { x: usize, y: usize },
    top: struct { x: usize },
    bottom: struct { x: usize },
    left: struct { y: usize },
    right: struct { y: usize },
    top_left: void,
    top_right: void,
    bottom_left: void,
    bottom_right: void,

    fn getCoords(self: TileValue, tile_type: TileType) struct { usize, usize } {
        return switch (tile_type) {
            .center => .{ self.center.x, self.center.y },
            .top => .{ self.top.x, 0 },
            .bottom => .{ self.bottom.x, y_len - 1 },
            .left => .{ 0, self.left.y },
            .right => .{ x_len - 1, self.right.y },
            .top_left => .{ 0, 0 },
            .top_right => .{ x_len - 1, 0 },
            .bottom_left => .{ 0, y_len - 1 },
            .bottom_right => .{ x_len - 1, y_len - 1 },
        };
    }
};

const TileType = enum {
    center,
    top,
    bottom,
    left,
    right,
    top_left,
    top_right,
    bottom_left,
    bottom_right,

    fn hasTop(self: TileType) bool {
        return switch (self) {
            .center, .bottom, .left, .right, .bottom_left, .bottom_right => true,
            else => false,
        };
    }

    fn hasBottom(self: TileType) bool {
        return switch (self) {
            .center, .top, .left, .right, .top_left, .top_right => true,
            else => false,
        };
    }

    fn hasLeft(self: TileType) bool {
        return switch (self) {
            .center, .top, .bottom, .right, .top_right, .bottom_right => true,
            else => false,
        };
    }

    fn hasRight(self: TileType) bool {
        return switch (self) {
            .center, .top, .bottom, .left, .top_left, .bottom_left => true,
            else => false,
        };
    }

    fn hasTopLeft(self: TileType) bool {
        return switch (self) {
            .center, .bottom, .right, .bottom_right => true,
            else => false,
        };
    }

    fn hasTopRight(self: TileType) bool {
        return switch (self) {
            .center, .bottom, .left, .bottom_left => true,
            else => false,
        };
    }

    fn hasBottomLeft(self: TileType) bool {
        return switch (self) {
            .center, .top, .right, .top_right => true,
            else => false,
        };
    }

    fn hasBottomRight(self: TileType) bool {
        return switch (self) {
            .center, .top, .left, .top_left => true,
            else => false,
        };
    }
};
