const std = @import("std");
const List = std.ArrayList;
const Random = std.Random;
const Allocator = std.mem.Allocator;

pub const Tile = struct { x: isize, y: isize };

const Self = @This();

ptr: *anyopaque,
vtable: *const VTable,

const VTable = struct {
    next: *const fn (ptr: *anyopaque) void,
    clear: *const fn (ptr: *anyopaque) void,
    randomize: *const fn (ptr: *anyopaque, rng: Random) void,
    setTile: *const fn (ptr: *anyopaque, x: isize, y: isize, tile: bool) void,
    setTiles: *const fn (ptr: *anyopaque, x: isize, y: isize, tiles: []Tile) void,
    getTiles: *const fn (ptr: *anyopaque, x_start: isize, y_start: isize, x_end: isize, y_end: isize, ally: Allocator) List(Tile),
};

pub fn init(
    ptr: anytype,
    comptime nextFn: *const fn (ptr: @TypeOf(ptr)) void,
    comptime clearFn: *const fn (ptr: @TypeOf(ptr)) void,
    comptime randomizeFn: *const fn (ptr: @TypeOf(ptr), rng: Random) void,
    comptime setTileFn: *const fn (ptr: @TypeOf(ptr), x: isize, y: isize, tile: bool) void,
    comptime setTilesFn: *const fn (ptr: @TypeOf(ptr), x: isize, y: isize, tiles: []Tile) void,
    comptime getTilesFn: *const fn (ptr: @TypeOf(ptr), x_start: isize, y_start: isize, x_end: isize, y_end: isize, ally: Allocator) List(Tile),
) Self {
    const Ptr = @TypeOf(ptr);
    const funs = struct {
        fn next(pointer: *anyopaque) void {
            const self: Ptr = @ptrCast(@alignCast(pointer));
            nextFn(self);
        }
        fn clear(pointer: *anyopaque) void {
            const self: Ptr = @ptrCast(@alignCast(pointer));
            clearFn(self);
        }
        fn randomize(pointer: *anyopaque, rng: Random) void {
            const self: Ptr = @ptrCast(@alignCast(pointer));
            randomizeFn(self, rng);
        }
        fn setTile(pointer: *anyopaque, x: isize, y: isize, tile: bool) void {
            const self: Ptr = @ptrCast(@alignCast(pointer));
            setTileFn(self, x, y, tile);
        }
        fn setTiles(pointer: *anyopaque, x: isize, y: isize, tiles: []Tile) void {
            const self: Ptr = @ptrCast(@alignCast(pointer));
            setTilesFn(self, x, y, tiles);
        }
        fn getTiles(pointer: *anyopaque, x_start: isize, y_start: isize, x_end: isize, y_end: isize, ally: Allocator) List(Tile) {
            const self: Ptr = @ptrCast(@alignCast(pointer));
            return getTilesFn(self, x_start, y_start, x_end, y_end, ally);
        }
    };
    return .{
        .ptr = ptr,
        .vtable = &.{
            .next = funs.next,
            .clear = funs.clear,
            .randomize = funs.randomize,
            .setTile = funs.setTile,
            .setTiles = funs.setTiles,
            .getTiles = funs.getTiles,
        },
    };
}

pub inline fn next(self: Self) void {
    self.vtable.next(self.ptr);
}

pub inline fn clear(self: Self) void {
    self.vtable.clear(self.ptr);
}

pub inline fn randomize(self: Self, rng: Random) void {
    self.vtable.randomize(self.ptr, rng);
}

pub inline fn setTile(self: Self, x: isize, y: isize, tile: bool) void {
    self.vtable.setTile(self.ptr, x, y, tile);
}

pub inline fn setTiles(self: Self, x: isize, y: isize, tiles: []Tile) void {
    self.vtable.setTiles(self.ptr, x, y, tiles);
}

pub inline fn getTiles(self: Self, x_start: isize, y_start: isize, x_end: isize, y_end: isize, ally: Allocator) List(Tile) {
    return self.vtable.getTiles(self.ptr, x_start, y_start, x_end, y_end, ally);
}
