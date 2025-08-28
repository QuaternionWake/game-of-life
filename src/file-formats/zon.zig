const std = @import("std");
const List = std.array_list.Managed;
const Allocator = std.mem.Allocator;

const Pattern = @import("../Pattern.zig");

pub fn fromZon(str: [:0]const u8, ally: Allocator) !Pattern {
    const slice = try std.zon.parse.fromSlice(Pattern.Slice, ally, str, null, .{});
    defer ally.free(slice.name);
    defer ally.free(slice.tiles);
    return slice.toPattern(ally);
}

pub fn toZon(pat: Pattern, ally: Allocator) ![]u8 {
    const slice = Pattern.Slice.fromPattern(pat);
    var list = List(u8).init(ally);
    const writer = list.writer();
    try std.zon.stringify.serialize(slice, .{}, writer);
    return list.toOwnedSlice();
}
