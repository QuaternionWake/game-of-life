const std = @import("std");
const List = std.ArrayList;
const Allocator = std.mem.Allocator;

const Tile = @import("game-of-life.zig").Tile;
const TileList = @import("game-of-life.zig").TileList;

pub const Pattern = struct {
    name: List(u8),
    tiles: TileList,

    pub fn init(name: []const u8, tiles: []const Tile, ally: Allocator) !Pattern {
        var name_string = try List(u8).initCapacity(ally, name.len + 1);
        name_string.appendSliceAssumeCapacity(name);
        name_string.appendAssumeCapacity(0);
        var tile_list = try TileList.initCapacity(ally, tiles.len);
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
};

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

    pub fn getTiles(self: PatternList, idx: usize) []Tile {
        return self.patterns.items[idx].tiles.items;
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
