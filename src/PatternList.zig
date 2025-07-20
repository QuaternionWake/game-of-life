const std = @import("std");
const List = std.ArrayList;
const Allocator = std.mem.Allocator;

const file_formats = @import("file-formats.zig");
const Tile = @import("GameOfLife.zig").Tile;
const Pattern = @import("Pattern.zig");
const Category = @import("PatternLibrary.zig").Category;
const resources = @import("resources");

patterns: List(Pattern),
allocator: Allocator,

const Self = @This();

pub fn init(ally: Allocator, comptime category: Category) !Self {
    var pattern_list = List(Pattern).init(ally);
    // Couldn't get it to parse at comptime ¯\_(ツ)_/¯
    if (category != .Others) {
        const rles = @field(resources, @tagName(category));
        for (rles) |rle| {
            const pat = file_formats.fromRle(rle, ally) catch continue;
            pattern_list.append(pat) catch continue;
        }
    } else blk: {
        const path = std.fs.getAppDataDir(ally, "game-of-life") catch break :blk;
        defer ally.free(path);
        var dir = std.fs.openDirAbsolute(path, .{ .iterate = true }) catch break :blk;
        defer dir.close();
        var iter = dir.iterateAssumeFirstIteration();
        while (iter.next() catch null) |entry| {
            if (entry.kind != .file) continue;

            const externsion_start = std.mem.lastIndexOfScalar(u8, entry.name, '.') orelse continue;
            const file_type = file_formats.Formats.fromString(entry.name[externsion_start..]) orelse continue;
            const file = dir.openFile(entry.name, .{}) catch continue;
            defer file.close();
            const str = file.readToEndAllocOptions(ally, std.math.maxInt(usize), null, @alignOf(u8), 0) catch continue;
            defer ally.free(str);
            var pattern = switch (file_type) {
                .Zon => file_formats.fromZon(str, ally) catch continue,
                .Rle => file_formats.fromRle(str, ally) catch continue,
            };
            if (pattern.name.len == 0) {
                pattern.setName(entry.name) catch continue;
            }
            pattern_list.append(pattern) catch continue;
        }
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
        list.appendAssumeCapacity(@ptrCast(pat.name));
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
