const std = @import("std");
const math = std.math;
const List = std.array_list.Managed;
const Random = std.Random;
const Allocator = std.mem.Allocator;

const Gol = @import("../GameOfLife.zig");
const Tile = Gol.Tile;
const UpgradableLock = @import("../UpgradableLock.zig");

const Board = []bool;

front_board: Board,
back_board: Board,
flipped: bool = false,
x_len: usize = 256,
y_len: usize = 256,
ally: Allocator,
x_wrap: Wrap = .Normal,
y_wrap: Wrap = .Normal,

lock: UpgradableLock = .{},

pub const Wrap = enum { None, Normal, Inverted };

const Self = @This();

pub fn init(rng: Random, ally: Allocator) !Self {
    var self = Self{
        .front_board = undefined,
        .back_board = undefined,
        .ally = ally,
    };
    self.front_board = try ally.alloc(bool, self.x_len * self.y_len);
    self.back_board = try ally.alloc(bool, self.x_len * self.y_len);

    self.randomize(rng);
    return self;
}

pub fn deinit(self: *Self) void {
    self.ally.free(self.front_board);
    self.ally.free(self.back_board);
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

pub fn setXLen(self: *Self, new_len: usize) void {
    self.lock.lock();
    defer self.lock.unlock();
    const width = @min(self.x_len, new_len);
    const new_board = self.ally.alloc(bool, new_len * self.y_len) catch unreachable;
    const new_back_board = self.ally.alloc(bool, new_len * self.y_len) catch unreachable;
    const active_board = self.getBoard();
    for (0..self.y_len) |y| {
        for (0..width) |x| {
            new_board[y * new_len + x] = active_board[y * self.x_len + x];
        }
    }
    self.ally.free(self.front_board);
    self.ally.free(self.back_board);
    self.front_board = new_board;
    self.back_board = new_back_board;
    self.flipped = false;
    self.x_len = new_len;
}

pub fn setYLen(self: *Self, new_len: usize) void {
    self.lock.lock();
    defer self.lock.unlock();
    self.front_board = self.ally.realloc(self.front_board, self.x_len * new_len) catch unreachable;
    self.back_board = self.ally.realloc(self.back_board, self.x_len * new_len) catch unreachable;
    self.y_len = new_len;
}

pub fn setXWrap(self: *Self, wrap: Wrap) void {
    self.lock.lock();
    defer self.lock.unlock();
    self.x_wrap = wrap;
}

pub fn setYWrap(self: *Self, wrap: Wrap) void {
    self.lock.lock();
    defer self.lock.unlock();
    self.y_wrap = wrap;
}

fn clear(self: *Self) void {
    self.lock.lock();
    defer self.lock.unlock();
    const board = self.getBoard();
    for (board) |*tile| {
        tile.* = false;
    }
}

fn randomize(self: *Self, rng: Random) void {
    self.lock.lock();
    defer self.lock.unlock();
    const board = self.getBoard();
    for (board) |*tile| {
        tile.* = rng.boolean();
    }
}

fn setTile(self: *Self, x: isize, y: isize, tile: bool) void {
    self.lock.lock();
    defer self.lock.unlock();
    const board = self.getBoard();
    if (x >= 0 and x < self.x_len and y >= 0 and y < self.y_len) {
        self.setTileBoard(board, @intCast(x), @intCast(y), tile);
    }
}

fn setTiles(self: *Self, x: isize, y: isize, tiles: []Tile) void {
    self.lock.lock();
    defer self.lock.unlock();
    const board = self.getBoard();
    for (tiles) |orig_tile| {
        const tile = .{ .x = orig_tile.x + x, .y = orig_tile.y + y };
        if (tile.x >= 0 and tile.x < self.x_len and tile.y >= 0 and tile.y < self.y_len) {
            self.setTileBoard(board, @intCast(tile.x), @intCast(tile.y), true);
        }
    }
}

fn getTiles(self: *Self, x_start: isize, y_start: isize, x_end: isize, y_end: isize, ally: Allocator) List(Tile) {
    self.lock.lockShared();
    defer self.lock.unlockShared();
    const board = self.getBoard();
    // no shadowning :'(
    const x_start_: usize = @intCast(@max(x_start, 0));
    const y_start_: usize = @intCast(@max(y_start, 0));
    const x_end_ = math.lossyCast(usize, @min(x_end, @as(isize, @intCast(self.x_len))));
    const y_end_ = math.lossyCast(usize, @min(y_end, @as(isize, @intCast(self.y_len))));

    var tiles = List(Tile).init(ally);
    if (y_start_ > y_end_ or x_start_ > x_end_) return tiles;
    for (y_start_..y_end_) |y| {
        for (x_start_..x_end_) |x| {
            if (self.getTileBoard(board, x, y)) {
                tiles.append(.{ .x = @intCast(x), .y = @intCast(y) }) catch return tiles;
            }
        }
    }
    return tiles;
}

fn next(self: *Self) void {
    // not having this **ZERO NANOSECOND** sleep here somehow causes the game
    // thread to near-permanantly hog the lock on this game causing the UI to
    // lock up if the target gens/s is larger than actual gens/s
    std.Thread.sleep(0);
    self.lock.lockUpgradable();

    const read_board = self.getBoard();
    const write_board = self.getInactiveBoard();

    for (1..self.x_len - 1) |x| {
        for (1..self.y_len - 1) |y| {
            const tile = self.nextTile(read_board, x, y);
            self.setTileBoard(write_board, x, y, tile);
        }
    }
    for (0..self.x_len) |x| {
        const tile_1 = self.nextTileWrapping(read_board, x, 0);
        self.setTileBoard(write_board, x, 0, tile_1);
        const tile_2 = self.nextTileWrapping(read_board, x, self.y_len - 1);
        self.setTileBoard(write_board, x, self.y_len - 1, tile_2);
    }
    for (1..self.y_len - 1) |y| {
        const tile_1 = self.nextTileWrapping(read_board, 0, y);
        self.setTileBoard(write_board, 0, y, tile_1);
        const tile_2 = self.nextTileWrapping(read_board, self.x_len - 1, y);
        self.setTileBoard(write_board, self.x_len - 1, y, tile_2);
    }
    self.lock.lockUpgrade();
    defer self.lock.unlock();

    self.flipped = !self.flipped;
}

fn getBoard(self: *Self) Board {
    if (self.flipped) {
        return self.back_board;
    } else {
        return self.front_board;
    }
}

fn getInactiveBoard(self: *Self) Board {
    if (self.flipped) {
        return self.front_board;
    } else {
        return self.back_board;
    }
}

fn nextTile(self: Self, board: Board, x: usize, y: usize) bool {
    const count =
        // Edges
        @as(u8, @intFromBool(self.getTileBoard(board, x, y - 1))) +
        @as(u8, @intFromBool(self.getTileBoard(board, x, y + 1))) +
        @as(u8, @intFromBool(self.getTileBoard(board, x - 1, y))) +
        @as(u8, @intFromBool(self.getTileBoard(board, x + 1, y))) +

        // Corners
        @as(u8, @intFromBool(self.getTileBoard(board, x - 1, y - 1))) +
        @as(u8, @intFromBool(self.getTileBoard(board, x + 1, y - 1))) +
        @as(u8, @intFromBool(self.getTileBoard(board, x - 1, y + 1))) +
        @as(u8, @intFromBool(self.getTileBoard(board, x + 1, y + 1)));

    if (self.getTileBoard(board, x, y)) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}

fn nextTileWrapping(self: Self, board: Board, x: usize, y: usize) bool {
    const x_: isize = @intCast(x);
    const y_: isize = @intCast(y);
    const count =
        // Edges
        @as(u8, @intFromBool(self.getTileBoardWrapping(board, x_, y_ - 1))) +
        @as(u8, @intFromBool(self.getTileBoardWrapping(board, x_, y_ + 1))) +
        @as(u8, @intFromBool(self.getTileBoardWrapping(board, x_ - 1, y_))) +
        @as(u8, @intFromBool(self.getTileBoardWrapping(board, x_ + 1, y_))) +

        // Corners
        @as(u8, @intFromBool(self.getTileBoardWrapping(board, x_ - 1, y_ - 1))) +
        @as(u8, @intFromBool(self.getTileBoardWrapping(board, x_ + 1, y_ - 1))) +
        @as(u8, @intFromBool(self.getTileBoardWrapping(board, x_ - 1, y_ + 1))) +
        @as(u8, @intFromBool(self.getTileBoardWrapping(board, x_ + 1, y_ + 1)));

    if (self.getTileBoard(board, x, y)) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}

fn getTileBoard(self: Self, board: Board, x: usize, y: usize) bool {
    return board[y * self.x_len + x];
}

// Only does wrapping on on tile past the edge exactly, not in general
fn getTileBoardWrapping(self: Self, board: Board, x: isize, y: isize) bool {
    const x_ = blk: {
        const x2: usize = switch (self.x_wrap) {
            .None => if (x == -1 or x == self.x_len) return false else @intCast(x),
            .Normal, .Inverted => if (x == -1) self.x_len - 1 else if (x == self.x_len) 0 else @intCast(x),
        };
        break :blk if (self.y_wrap == .Inverted and (y == -1 or y == self.y_len)) self.x_len - 1 - x2 else x2;
    };
    const y_ = blk: {
        const y2: usize = switch (self.y_wrap) {
            .None => if (y == -1 or y == self.y_len) return false else @intCast(y),
            .Normal, .Inverted => if (y == -1) self.y_len - 1 else if (y == self.y_len) 0 else @intCast(y),
        };
        break :blk if (self.x_wrap == .Inverted and (x == -1 or x == self.x_len)) self.y_len - 1 - y2 else y2;
    };
    return board[y_ * self.x_len + x_];
}

fn setTileBoard(self: Self, board: Board, x: usize, y: usize, tile: bool) void {
    board[y * self.x_len + x] = tile;
}
