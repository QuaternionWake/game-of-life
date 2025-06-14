const std = @import("std");
const List = std.ArrayList;
const Allocator = std.mem.Allocator;

const Tile = @import("GameOfLife.zig").Tile;

pub const Pattern = struct {
    name: List(u8),
    tiles: List(Tile),
    orientation: Orientation = .{},

    pub fn init(name: []const u8, tiles: []const Tile, ally: Allocator) !Pattern {
        var name_string = try List(u8).initCapacity(ally, name.len + 1);
        name_string.appendSliceAssumeCapacity(name);
        name_string.appendAssumeCapacity(0);
        var tile_list = try List(Tile).initCapacity(ally, tiles.len);
        tile_list.appendSliceAssumeCapacity(tiles);
        return .{
            .name = name_string,
            .tiles = tile_list,
        };
    }

    pub fn deinit(self: Pattern) void {
        self.name.deinit();
        self.tiles.deinit();
    }

    pub fn getTiles(self: Pattern, ally: Allocator) !List(Tile) {
        var oriented_tiles = try List(Tile).initCapacity(ally, self.tiles.items.len);
        for (self.tiles.items) |tile| {
            const oriented_tile = orientTile(tile, self.orientation);
            oriented_tiles.appendAssumeCapacity(oriented_tile);
        }
        return oriented_tiles;
    }

    pub fn setTiles(self: *Pattern, tiles: []const Tile) !void {
        self.tiles.clearRetainingCapacity();
        try self.tiles.appendSlice(tiles);
    }
};

pub const Orientation = struct {
    rotation: Rotation = .Zero,
    flipped: bool = false,

    const Rotation = enum { Zero, Three, Six, Nine };

    pub fn rotateCW(self: *Orientation) void {
        self.rotation = switch (self.rotation) {
            .Zero => .Three,
            .Three => .Six,
            .Six => .Nine,
            .Nine => .Zero,
        };
    }

    pub fn rotateCCW(self: *Orientation) void {
        self.rotation = switch (self.rotation) {
            .Zero => .Nine,
            .Three => .Zero,
            .Six => .Three,
            .Nine => .Six,
        };
    }

    pub fn flipH(self: *Orientation) void {
        self.flipped = !self.flipped;
        self.rotation = switch (self.rotation) {
            .Zero => .Zero,
            .Three => .Nine,
            .Six => .Six,
            .Nine => .Three,
        };
    }

    pub fn flipV(self: *Orientation) void {
        self.flipped = !self.flipped;
        self.rotation = switch (self.rotation) {
            .Zero => .Six,
            .Three => .Three,
            .Six => .Zero,
            .Nine => .Nine,
        };
    }
};

fn orientTile(tile: Tile, orientation: Orientation) Tile {
    var new_tile = tile;
    if (orientation.flipped) {
        new_tile.x = -tile.x;
    }
    const newer_tile: Tile = switch (orientation.rotation) {
        .Zero => .{ .x = new_tile.x, .y = new_tile.y },
        .Three => .{ .x = -new_tile.y, .y = new_tile.x },
        .Six => .{ .x = -new_tile.x, .y = -new_tile.y },
        .Nine => .{ .x = new_tile.y, .y = -new_tile.x },
    };
    return newer_tile;
}

pub const PatternList = struct {
    patterns: List(Pattern),
    allocator: Allocator,

    pub fn init(ally: Allocator) !PatternList {
        const patterns: [4]PatternSlice = @import("resources/patterns.zon");
        var pattern_list = try List(Pattern).initCapacity(ally, patterns.len);
        for (patterns) |pat| {
            pattern_list.appendAssumeCapacity(try pat.toPattern(ally));
        }
        return .{
            .patterns = pattern_list,
            .allocator = ally,
        };
    }

    pub fn deinit(self: PatternList) void {
        for (self.patterns.items) |p| {
            p.deinit();
        }
        self.patterns.deinit();
    }

    pub fn getNames(self: PatternList, ally: Allocator) !List([*:0]const u8) {
        var list = try List([*:0]const u8).initCapacity(ally, self.patterns.items.len);
        for (self.patterns.items) |pat| {
            list.appendAssumeCapacity(@ptrCast(pat.name.items));
        }
        return list;
    }

    pub fn getTiles(self: PatternList, idx: usize, ally: Allocator) !List(Tile) {
        return self.patterns.items[idx].getTiles(ally);
    }

    pub fn getPattern(self: PatternList, idx: usize) Pattern {
        return self.patterns.items[idx];
    }

    pub fn getPatternRef(self: PatternList, idx: usize) *Pattern {
        return &self.patterns.items[idx];
    }

    pub fn insert(self: *PatternList, pattern: Pattern) !void {
        try self.patterns.append(pattern);
    }
};

const PatternSlice = struct {
    name: []const u8,
    tiles: []const Tile,

    pub fn toPattern(self: PatternSlice, ally: Allocator) !Pattern {
        return Pattern.init(self.name, self.tiles, ally);
    }

    pub fn fromPattern(pattern: Pattern) PatternSlice {
        return .{
            .name = pattern.name.items,
            .tiles = pattern.tiles.items,
        };
    }
};
