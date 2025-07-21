const std = @import("std");
const mem = std.mem;

const zon = @import("file-formats/zon.zig");
const rle = @import("file-formats/rle.zig");

pub const Formats = enum {
    Zon,
    Rle,

    pub fn toString(self: Formats) []const u8 {
        return switch (self) {
            .Zon => ".zon",
            .Rle => ".rle",
        };
    }

    pub fn fromString(str: []const u8) ?Formats {
        return if (mem.eql(u8, str, ".zon"))
            .Zon
        else if (mem.eql(u8, str, ".rle"))
            .Rle
        else
            null;
    }
};

pub const fromZon = zon.fromZon;
pub const toZon = zon.toZon;

pub const fromRle = rle.fromRle;
pub const toRle = rle.toRle;
