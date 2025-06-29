const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const List = std.ArrayList;
const Allocator = mem.Allocator;

const Pattern = @import("Pattern.zig");
const Tile = @import("GameOfLife.zig").Tile;

pub const LoadableFormats = enum {
    Zon,
    Rle,

    pub fn toString(self: LoadableFormats) []const u8 {
        return switch (self) {
            .Zon => ".zon",
            .Rle => ".rle",
        };
    }

    pub fn fromString(str: []const u8) ?LoadableFormats {
        return if (mem.eql(u8, str, ".zon"))
            .Zon
        else if (mem.eql(u8, str, ".rle"))
            .Rle
        else
            null;
    }
};

// Zon
// ----------------
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

// Rle
// ----------------
pub fn fromRle(str: []const u8, ally: Allocator) !Pattern {
    var name: []const u8 = "";
    var x_offset: ?isize = null;
    var y_offset: ?isize = null;

    var iter = mem.tokenizeAny(u8, str, "\n\r");

    // # lines
    while (iter.peek()) |line| {
        if (line[0] != '#') break;
        if (line.len < 2) continue;
        switch (getRleLineType(line)) {
            .Name => {
                name = mem.trim(u8, line[2..], " \t");
            },
            .TopLeftCoords => blk: {
                var tlcoord_iter = mem.tokenizeAny(u8, line[2..], " \t");
                const x_str = tlcoord_iter.next() orelse break :blk;
                x_offset = fmt.parseInt(isize, x_str, 0) catch null;
                const y_str = tlcoord_iter.next() orelse break :blk;
                y_offset = fmt.parseInt(isize, y_str, 0) catch null;
            },
            .Comment, .DiscoveryInfo, .Rules, .Unknown => {},
        }
        _ = iter.next();
    }

    // Header
    blk: {
        const header = iter.next() orelse return error.ParseError;
        var chunk_iter = mem.tokenizeScalar(u8, header, ',');
        const x_chunk = chunk_iter.next() orelse break :blk;
        const y_chunk = chunk_iter.next() orelse break :blk;
        // const rule_chunk = chunk_iter.next();
        if (x_offset == null) x: {
            const x_width: usize = x2: {
                const eql_idx = mem.indexOfScalar(u8, x_chunk, '=') orelse break :x;
                if (eql_idx + 1 == x_chunk.len) break :x;
                const x_str = mem.trim(u8, x_chunk[(eql_idx + 1)..], " \t");
                break :x2 fmt.parseInt(usize, x_str, 0) catch break :x;
            };
            x_offset = -@as(isize, @intCast(x_width / 2));
        }
        if (y_offset == null) y: {
            const y_width: usize = y2: {
                const eql_idy = mem.indexOfScalar(u8, y_chunk, '=') orelse break :y;
                if (eql_idy + 1 == y_chunk.len) break :y;
                const y_str = mem.trim(u8, y_chunk[(eql_idy + 1)..], " \t");
                break :y2 fmt.parseInt(usize, y_str, 0) catch break :y;
            };
            y_offset = -@as(isize, @intCast(y_width / 2));
        }
    }

    var tiles = List(Tile).init(ally);
    defer tiles.deinit();

    // Body
    {
        const rest = iter.rest();
        const end = mem.indexOfScalar(u8, rest, '!') orelse rest.len;
        const body = rest[0..end];
        var body_iter = mem.splitScalar(u8, body, '$');
        const x_start = x_offset orelse 0;
        const y_start = y_offset orelse 0;

        var x = x_start;
        var y = y_start;
        while (body_iter.next()) |chunk| {
            var num_start: usize = 0;
            var in_number = false;
            var run_len: ?usize = null;
            for (chunk, 0..) |c, i| {
                if (c >= '0' and c <= '9') {
                    if (!in_number) {
                        in_number = true;
                        num_start = i;
                    }
                } else if (in_number) {
                    in_number = false;
                    run_len = fmt.parseInt(usize, chunk[num_start..i], 10) catch break;
                }

                switch (c) {
                    '\n', '\r' => continue,

                    'b' => {
                        x += @intCast(run_len orelse 1);
                        run_len = null;
                    },

                    'o', 'x', 'y', 'z' => {
                        if (run_len) |len| {
                            for (0..(len)) |_| {
                                try tiles.append(.{ .x = x, .y = y });
                                x += 1;
                            }
                            run_len = null;
                        } else {
                            try tiles.append(.{ .x = x, .y = y });
                            x += 1;
                        }
                    },

                    else => {},
                }
            }
            if (in_number) blk: {
                run_len = fmt.parseInt(usize, chunk[num_start..], 10) catch break :blk;
                y += @intCast(run_len.? -| 1);
            }

            x = x_start;
            y += 1;
        }
    }

    return Pattern.init(name, tiles.items, ally);
}

fn getRleLineType(line: []const u8) RleCommentType {
    return switch (line[1]) {
        'C', 'c' => .Comment,
        'N' => .Name,
        'O' => .DiscoveryInfo,
        'P', 'R' => .TopLeftCoords,
        'r' => .Rules,
        else => .Unknown,
    };
}

const RleCommentType = enum { Name, Comment, DiscoveryInfo, TopLeftCoords, Rules, Unknown };
