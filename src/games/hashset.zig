const std = @import("std");
const math = std.math;
const Random = std.Random;
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const Gol = @import("../game-of-life.zig");
const Tile = Gol.Tile;
const TileList = Gol.TileList;

const Board = std.AutoHashMap(Gol.Tile, void);

board: Board,
ally: Allocator,

mutex: Mutex = .{},

const Self = @This();

pub fn init(rng: Random, ally: Allocator) Self {
    var self = Self{
        .board = Board.init(ally),
        .ally = ally,
    };
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
    self.mutex.lock();
    defer self.mutex.unlock();
    self.board.clearRetainingCapacity();
}

fn randomize(self: *Self, rng: Random) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    self.board.clearRetainingCapacity();
    for (0..(1024 * 32)) |_| {
        const x: isize = @intFromFloat(@floor(rng.floatNorm(f64) * 128));
        const y: isize = @intFromFloat(@floor(rng.floatNorm(f64) * 128));
        self.board.put(.{ .x = x, .y = y }, {}) catch {};
    }
}

fn setTile(self: *Self, x: isize, y: isize, tile: bool) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    if (tile) {
        self.board.put(.{ .x = x, .y = y }, {}) catch {};
    } else {
        _ = self.board.remove(.{ .x = x, .y = y });
    }
}

fn setTiles(self: *Self, x: isize, y: isize, tiles: []Tile) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    for (tiles) |orig_tile| {
        const tile = Tile{ .x = orig_tile.x + x, .y = orig_tile.y + y };
        self.board.put(tile, {}) catch {};
    }
}

fn getTiles(self: *Self, x_start: isize, y_start: isize, x_end: isize, y_end: isize, ally: Allocator) Gol.TileList {
    var tiles = Gol.TileList.init(ally);

    self.mutex.lock();
    defer self.mutex.unlock();

    var iter = self.board.iterator();
    while (iter.next()) |tile| {
        const x = tile.key_ptr.x;
        const y = tile.key_ptr.y;
        if (x >= x_start and x < x_end and y >= y_start and y < y_end) {
            tiles.append(.{ .x = x, .y = y }) catch return tiles;
        }
    }
    return tiles;
}

fn next(self: *Self) void {
    var new_board = Board.init(self.ally);
    var check_board = makeCheckBoard(self.board, self.ally);
    defer check_board.deinit();

    var iter = check_board.iterator();
    while (iter.next()) |tile| {
        const x = tile.key_ptr.x;
        const y = tile.key_ptr.y;
        if (nextTile(self.board, x, y)) {
            new_board.put(.{ .x = x, .y = y }, {}) catch {};
        }
    }
    var old_board = self.board;
    self.board = new_board;

    self.mutex.lock();
    defer self.mutex.unlock();

    old_board.deinit();
}

fn makeCheckBoard(board: Board, ally: Allocator) Board {
    var check_board = Board.init(ally);
    var iter = board.iterator();
    while (iter.next()) |tile| {
        const x = tile.key_ptr.x;
        const y = tile.key_ptr.y;
        check_board.put(.{ .x = x - 1, .y = y - 1 }, {}) catch {};
        check_board.put(.{ .x = x + 0, .y = y - 1 }, {}) catch {};
        check_board.put(.{ .x = x + 1, .y = y - 1 }, {}) catch {};
        check_board.put(.{ .x = x - 1, .y = y + 0 }, {}) catch {};
        check_board.put(.{ .x = x + 0, .y = y + 0 }, {}) catch {};
        check_board.put(.{ .x = x + 1, .y = y + 0 }, {}) catch {};
        check_board.put(.{ .x = x - 1, .y = y + 1 }, {}) catch {};
        check_board.put(.{ .x = x + 0, .y = y + 1 }, {}) catch {};
        check_board.put(.{ .x = x + 1, .y = y + 1 }, {}) catch {};
    }
    return check_board;
}

fn nextTile(board: Board, x: isize, y: isize) bool {
    const count =
        @as(u8, @intFromBool(board.contains(.{ .x = x - 1, .y = y - 1 }))) +
        @as(u8, @intFromBool(board.contains(.{ .x = x + 0, .y = y - 1 }))) +
        @as(u8, @intFromBool(board.contains(.{ .x = x + 1, .y = y - 1 }))) +
        @as(u8, @intFromBool(board.contains(.{ .x = x - 1, .y = y + 0 }))) +
        @as(u8, @intFromBool(board.contains(.{ .x = x + 1, .y = y + 0 }))) +
        @as(u8, @intFromBool(board.contains(.{ .x = x - 1, .y = y + 1 }))) +
        @as(u8, @intFromBool(board.contains(.{ .x = x + 0, .y = y + 1 }))) +
        @as(u8, @intFromBool(board.contains(.{ .x = x + 1, .y = y + 1 })));

    if (board.contains(.{ .x = x, .y = y })) {
        return count == 2 or count == 3;
    } else {
        return count == 3;
    }
}
