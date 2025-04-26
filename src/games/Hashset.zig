const std = @import("std");
const math = std.math;
const List = std.ArrayList;
const Random = std.Random;
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const RwLock = std.Thread.RwLock;

const Gol = @import("../GameOfLife.zig");
const Tile = Gol.Tile;

const Board = std.AutoHashMap(Tile, void);

board: Board,
ally: Allocator,

rw_lock: RwLock = .{},
lock_upgrade_mutex: Mutex = .{},

const Self = @This();

pub fn init(rng: Random, ally: Allocator) Self {
    var self = Self{
        .board = Board.init(ally),
        .ally = ally,
    };
    self.randomize(rng);
    return self;
}

pub fn deinit(self: *Self) void {
    self.lock();
    defer self.unlock();
    self.board.deinit();
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
    self.lock();
    defer self.unlock();
    self.board.clearRetainingCapacity();
}

fn randomize(self: *Self, rng: Random) void {
    self.lock();
    defer self.unlock();
    self.board.clearRetainingCapacity();
    for (0..(1024 * 32)) |_| {
        const x: isize = @intFromFloat(@floor(rng.floatNorm(f64) * 128));
        const y: isize = @intFromFloat(@floor(rng.floatNorm(f64) * 128));
        self.board.put(.{ .x = x, .y = y }, {}) catch {};
    }
}

fn setTile(self: *Self, x: isize, y: isize, tile: bool) void {
    self.lock();
    defer self.unlock();
    if (tile) {
        self.board.put(.{ .x = x, .y = y }, {}) catch {};
    } else {
        _ = self.board.remove(.{ .x = x, .y = y });
    }
}

fn setTiles(self: *Self, x: isize, y: isize, tiles: []Tile) void {
    self.lock();
    defer self.unlock();
    for (tiles) |orig_tile| {
        const tile = Tile{ .x = orig_tile.x + x, .y = orig_tile.y + y };
        self.board.put(tile, {}) catch {};
    }
}

fn getTiles(self: *Self, x_start: isize, y_start: isize, x_end: isize, y_end: isize, ally: Allocator) List(Tile) {
    var tiles = List(Tile).init(ally);

    self.lockShared();
    defer self.unlockShared();

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

    self.lockUpgradable();
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

    self.lockUpgrade();
    defer self.unlock();

    var old_board = self.board;
    self.board = new_board;
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

fn lock(self: *Self) void {
    self.lock_upgrade_mutex.lock();
    self.rw_lock.lock();
    self.lock_upgrade_mutex.unlock();
}

fn lockShared(self: *Self) void {
    self.rw_lock.lockShared();
}

fn lockUpgradable(self: *Self) void {
    self.lock_upgrade_mutex.lock();
    self.rw_lock.lockShared();
}

fn lockUpgrade(self: *Self) void {
    self.rw_lock.unlockShared();
    self.rw_lock.lock();
    self.lock_upgrade_mutex.unlock();
}

fn unlock(self: *Self) void {
    self.rw_lock.unlock();
}

fn unlockShared(self: *Self) void {
    self.rw_lock.unlockShared();
}
