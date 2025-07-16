const std = @import("std");
const List = std.EnumArray;
const Allocator = std.mem.Allocator;

const PatternList = @import("PatternList.zig");
const Pattern = @import("Pattern.zig");

const Self = @This();

pub const Category = enum { Spaceships, Puffers, Oscilators, Guns, Methuselahs, @"Still lifes", Wicks, Others };

categories: List(Category, PatternList),

pub fn init(ally: Allocator) !Self {
    var categories = List(Category, PatternList).initUndefined();

    inline for (&categories.values, 0..) |*category, enum_idx| {
        category.* = try PatternList.init(ally, @enumFromInt(enum_idx));
    }

    return .{
        .categories = categories,
    };
}

pub fn deinit(self: *Self) void {
    for (self.categories.values) |category| {
        category.deinit();
    }
}

pub fn getCategory(self: *Self, category: Category) *PatternList {
    return self.categories.getPtr(category);
}

pub fn getPatternNames(self: *Self, ally: Allocator) !List(Category, [][*:0]const u8) {
    var result_list = List(Category, [][*:0]const u8).initUndefined();
    for (self.categories.values, &result_list.values) |cactegory, *result| {
        var list = try cactegory.getNames(ally);
        result.* = try list.toOwnedSlice();
    }
    return result_list;
}

pub fn getPattern(self: Self, idx: LibraryIndex) Pattern {
    const pat_list = self.categories.get(idx.category);
    return pat_list.getPattern(idx.index);
}

pub fn getPatternRef(self: Self, idx: LibraryIndex) *Pattern {
    const pat_list = self.categories.get(idx.category);
    return pat_list.getPatternRef(idx.index);
}

pub const LibraryIndex = struct {
    category: Category,
    index: usize,
};
