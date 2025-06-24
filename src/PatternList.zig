const std = @import("std");
const List = std.ArrayList;
const Allocator = std.mem.Allocator;

const Tile = @import("GameOfLife.zig").Tile;
const Pattern = @import("Pattern.zig");

patterns: List(Pattern),
allocator: Allocator,

const Self = @This();

pub fn init(ally: Allocator) !Self {
    const patterns: [4]Pattern.Slice = @import("resources/patterns.zon");
    var pattern_list = try List(Pattern).initCapacity(ally, patterns.len);
    for (patterns) |pat| {
        pattern_list.appendAssumeCapacity(try pat.toPattern(ally));
    }
    return .{
        .patterns = pattern_list,
        .allocator = ally,
    };
}

pub fn deinit(self: Self) void {
    for (self.patterns.items) |p| {
        p.deinit();
    }
    self.patterns.deinit();
}

pub fn getNames(self: Self, ally: Allocator) !List([*:0]const u8) {
    var list = try List([*:0]const u8).initCapacity(ally, self.patterns.items.len);
    for (self.patterns.items) |pat| {
        list.appendAssumeCapacity(@ptrCast(pat.name.items));
    }
    return list;
}

pub fn getTiles(self: Self, idx: usize, ally: Allocator) !List(Tile) {
    return self.patterns.items[idx].getTiles(ally);
}

pub fn getPattern(self: Self, idx: usize) Pattern {
    return self.patterns.items[idx];
}

pub fn getPatternRef(self: Self, idx: usize) *Pattern {
    return &self.patterns.items[idx];
}

pub fn insert(self: *Self, pattern: Pattern) !void {
    try self.patterns.append(pattern);
}
