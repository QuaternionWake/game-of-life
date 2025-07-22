const std = @import("std");
const List = std.EnumArray;
const Allocator = std.mem.Allocator;
const mem = std.mem;
const fs = std.fs;

const PatternList = @import("PatternList.zig");
const Pattern = @import("Pattern.zig");
const file_formats = @import("file-formats.zig");

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

pub fn savePattern(self: *Self, pat: Pattern, file_name: []const u8, ally: Allocator) !void {
    try self.categories.getPtr(.Others).insert(pat);

    const file = try getFile(file_name, .Rle, true, ally);
    defer file.close();

    const pat_str = try file_formats.toRle(pat, ally);
    defer ally.free(pat_str);

    try file.writeAll(pat_str);
}

const appname = "game-of-life";

fn getFile(name: []const u8, format: file_formats.Formats, create: bool, ally: Allocator) !fs.File {
    if (name.len == 0) return error.EmptyName;
    if (mem.indexOfScalar(u8, name, '/') != null or mem.indexOfScalar(u8, name, 0) != null) return error.InvalidName;

    const dir_path = try fs.getAppDataDir(ally, appname);
    defer ally.free(dir_path);
    const file = if (create) blk: {
        fs.makeDirAbsolute(dir_path) catch |err| if (err != error.PathAlreadyExists) return err;
        var dir = try fs.openDirAbsolute(dir_path, .{});
        defer dir.close();

        const filename = try mem.concat(ally, u8, &.{ name, format.toString() });
        defer ally.free(filename);
        break :blk dir.createFile(filename, .{});
    } else blk: {
        const file_path = try mem.concat(ally, u8, &.{ dir_path, name, format.toString() });
        break :blk fs.openFileAbsolute(file_path, .{});
    };

    return file;
}
