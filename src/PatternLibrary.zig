const std = @import("std");
const List = std.StringArrayHashMap;
const Allocator = std.mem.Allocator;

const PatternList = @import("PatternList.zig");

const Self = @This();

categories: List(PatternList),

pub fn init(category_names: []const []const u8, ally: Allocator) !Self {
    var categories = List(PatternList).init(ally);
    try categories.ensureTotalCapacity(category_names.len);

    for (category_names) |category| {
        const list = try PatternList.init(ally, category);
        categories.putAssumeCapacity(category, list);
    }

    return .{
        .categories = categories,
    };
}

pub fn deinit(self: *Self) void {
    for (self.categories.values()) |category| {
        category.deinit();
    }
    self.categories.deinit();
}

pub fn getCategory(self: *Self, category: []const u8) ?*PatternList {
    return self.categories.getPtr(category);
}
