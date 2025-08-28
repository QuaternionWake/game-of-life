const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const ascii = std.ascii;
const List = std.array_list.Managed;
const Allocator = mem.Allocator;

const Pattern = @import("../Pattern.zig");
const Tile = @import("../GameOfLife.zig").Tile;

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
        var rle_iter = RleTokenizer.init(iter.rest());

        const x_start = x_offset orelse 0;
        const y_start = y_offset orelse 0;

        var x = x_start;
        var y = y_start;

        var run_len: ?usize = null;
        while (rle_iter.next()) |token| {
            if (fmt.parseInt(usize, token, 10) catch null) |n| {
                run_len = n;
                continue;
            }

            if (token.len != 1) return error.ParseError;

            switch (token[0]) {
                'b' => x += @intCast(run_len orelse 1),
                'o', 'x', 'y', 'z' => if (run_len) |len| {
                    for (0..len) |_| {
                        try tiles.append(.{ .x = x, .y = y });
                        x += 1;
                    }
                } else {
                    try tiles.append(.{ .x = x, .y = y });
                    x += 1;
                },
                '$' => {
                    x = x_start;
                    y += @intCast(run_len orelse 1);
                },
                else => return error.ParseError,
            }
            run_len = null;
        }
    }

    return Pattern.init(name, tiles.items, ally);
}

const RleTokenizer = struct {
    buffer: []const u8,
    index: usize,

    fn init(buffer: []const u8) RleTokenizer {
        return .{
            .buffer = buffer,
            .index = 0,
        };
    }

    fn next(self: *RleTokenizer) ?[]const u8 {
        while (self.index < self.buffer.len and ascii.isWhitespace(self.buffer[self.index])) {
            self.index += 1;
        }
        const start = self.index;
        if (start == self.buffer.len or self.buffer[start] == '!') return null;

        if (ascii.isDigit(self.buffer[start])) {
            while (self.index < self.buffer.len and ascii.isDigit(self.buffer[self.index])) {
                self.index += 1;
            }
        } else {
            self.index += 1;
        }

        return self.buffer[start..self.index];
    }
};

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

pub fn toRle(pat: Pattern, ally: Allocator) ![:0]u8 {
    if (pat.tiles.len == 0) return error.EmptyPattern;

    const tiles = try ally.alloc(Tile, pat.tiles.len);
    defer ally.free(tiles);
    @memcpy(tiles, pat.tiles);
    const lessThan = struct {
        fn f(_: void, lhs: Tile, rhs: Tile) bool {
            return if (lhs.y == rhs.y) lhs.x < rhs.x else lhs.y < rhs.y;
        }
    }.f;
    std.mem.sort(Tile, tiles, {}, lessThan);

    const x_min, const y_min, const x_max, const y_max = blk: {
        var x_min: isize = std.math.maxInt(isize);
        var y_min: isize = std.math.maxInt(isize);
        var x_max: isize = std.math.minInt(isize);
        var y_max: isize = std.math.minInt(isize);
        for (tiles) |tile| {
            if (tile.x < x_min) x_min = tile.x;
            if (tile.y < y_min) y_min = tile.y;
            if (tile.x > x_max) x_max = tile.x;
            if (tile.y > y_max) y_max = tile.y;
        }
        break :blk .{ x_min, y_min, x_max, y_max };
    };

    var rle_ir = try RleIR.init(ally, x_min, tiles[0]);
    defer rle_ir.deinit();

    for (tiles[1..]) |tile| {
        try rle_ir.addTile(tile);
    }

    var rle = List(u8).init(ally);
    errdefer rle.deinit();
    const w = rle.writer();
    if (pat.name.len != 0) {
        try w.print("#N {s}\n", .{pat.name});
    }

    try w.print("x = {d}, y = {d}, rule = B3/S23\n", .{ x_max - x_min + 1, y_max - y_min + 1 });

    var line_len: usize = 0;
    for (rle_ir.runs.items) |run| {
        var buf: [70]u8 = undefined;
        const run_str = try if (run.len == 1)
            std.fmt.bufPrint(&buf, "{c}", .{run.char()})
        else
            std.fmt.bufPrint(&buf, "{d}{c}", .{ run.len, run.char() });
        if (line_len + run_str.len > 70) {
            try w.print("\n{s}", .{run_str});
            line_len = run_str.len;
        } else {
            try w.print("{s}", .{run_str});
            line_len += run_str.len;
        }
    }
    if (line_len + 1 > 70) {
        try w.print("\n!", .{});
    } else {
        try w.print("!", .{});
    }

    return try rle.toOwnedSliceSentinel(0);
}

const RleIR = struct {
    runs: List(Run),
    x_min: isize,
    prev_tile: Tile,

    fn init(ally: Allocator, x_min: isize, first_tile: Tile) !RleIR {
        var runs = List(Run).init(ally);
        errdefer runs.deinit();
        if (first_tile.x != x_min) {
            try runs.append(.dead(@intCast(first_tile.x - x_min)));
        }
        try runs.append(.live(1));

        return .{
            .runs = runs,
            .x_min = x_min,
            .prev_tile = first_tile,
        };
    }

    fn deinit(self: RleIR) void {
        self.runs.deinit();
    }

    fn addTile(self: *RleIR, tile: Tile) !void {
        if (tile.y != self.prev_tile.y) {
            try self.addLine(tile);
        } else if (tile.x != self.prev_tile.x + 1) {
            try self.addDead(tile);
        } else {
            try self.addLive(tile);
        }
    }

    fn addLive(self: *RleIR, tile: Tile) !void {
        const last = &self.runs.items[self.runs.items.len - 1];
        last.len += 1;
        self.prev_tile = tile;
    }

    fn addDead(self: *RleIR, tile: Tile) !void {
        try self.runs.append(.dead(@intCast(tile.x - self.prev_tile.x - 1)));
        try self.runs.append(.live(1));
        self.prev_tile = tile;
    }

    fn addLine(self: *RleIR, tile: Tile) !void {
        try self.runs.append(.line(@intCast(tile.y - self.prev_tile.y)));
        if (tile.x != self.x_min) {
            try self.runs.append(.dead(@intCast(tile.x - self.x_min)));
        }
        try self.runs.append(.live(1));
        self.prev_tile = tile;
    }

    const Run = struct {
        type: enum { live, dead, line },
        len: usize,

        fn live(n: usize) Run {
            return .{ .type = .live, .len = n };
        }

        fn dead(n: usize) Run {
            return .{ .type = .dead, .len = n };
        }

        fn line(n: usize) Run {
            return .{ .type = .line, .len = n };
        }

        fn char(self: Run) u8 {
            return switch (self.type) {
                .live => 'o',
                .dead => 'b',
                .line => '$',
            };
        }
    };
};
