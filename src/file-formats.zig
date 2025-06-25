const std = @import("std");
const List = std.ArrayList;
const Allocator = std.mem.Allocator;

const Pattern = @import("Pattern.zig");

// Zon
// ----------------
pub fn fromZon(str: [:0]const u8, ally: Allocator) !Pattern {
    const slice = try std.zon.parse.fromSlice(Pattern.Slice, ally, str, null, .{});
    return slice.toPattern(ally);
}

pub fn toZon(pat: Pattern, ally: Allocator) ![]u8 {
    const slice = Pattern.Slice.fromPattern(pat);
    var list = List(u8).init(ally);
    const writer = list.writer();
    try std.zon.stringify.serialize(slice, .{}, writer);
    return list.toOwnedSlice();
}
