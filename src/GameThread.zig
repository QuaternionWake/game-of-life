const std = @import("std");
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const Semaphore = Thread.Semaphore;
const List = std.array_list.Managed;

const Gol = @import("GameOfLife.zig");

const GameThread = @This();

const Message = union(enum) {
    pause: void,
    unpause: void,
    set_game_speed: u64,
    step: void,
    clear: void,
    randomize: void,
    end_game: void,
    set_tile: SetTileArgs,
    set_tiles: SetTilesArgs,
    change_game: Gol,
};

const SetTileArgs = struct { x: isize, y: isize, tile: bool };
// TODO: move pattern orientation to the setTiles() function so we can sort of
// pass a slice here (pasting from clipboard will porbably need to be handled
// differently)
const SetTilesArgs = struct { x: isize, y: isize, tiles: List(Gol.Tile) };

messages: MsgQueue = .{},
message_mutex: Mutex = .{},
message_count: Semaphore = .{},

game_paused: bool = false,

time_target_ns: u64 = std.time.ns_per_s / 60,

times: [16]u64 = std.mem.zeroes([16]u64),
time_idx: u4 = 0,

generation: u64 = 0,

pub fn run(self: *GameThread, gol: Gol) !void {
    var game = gol;
    var random = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = random.random();

    var timer = try std.time.Timer.start();
    var msg_wait_time: u64 = self.time_target_ns;

    while (true) {
        const msg: Message = blk: {
            if (!self.game_paused) {
                msg_wait_time = self.time_target_ns -| timer.read();
                self.message_count.timedWait(msg_wait_time) catch break :blk null;
            } else {
                self.message_count.wait();
            }
            self.message_mutex.lock();
            defer self.message_mutex.unlock();
            break :blk self.messages.pop();
        } orelse {
            timer.reset();
            game.next();
            self.times[self.time_idx] = timer.read();
            self.time_idx +%= 1;
            self.generation += 1;
            continue;
        };
        switch (msg) {
            .pause => self.game_paused = true,
            .unpause => self.game_paused = false,
            .set_game_speed => |val| self.time_target_ns = val,
            .step => {
                game.next();
                self.generation += 1;
            },
            .clear => {
                game.clear();
                self.generation = 0;
            },
            .randomize => {
                game.randomize(rng);
                self.generation = 0;
            },
            .end_game => break,
            .set_tile => |args| game.setTile(args.x, args.y, args.tile),
            .set_tiles => |args| {
                game.setTiles(args.x, args.y, args.tiles.items);
                args.tiles.deinit();
            },
            .change_game => |new_game| game = new_game,
        }
    }
}

// Fails silently if there's already 1024 messages in the queue
pub fn message(self: *GameThread, msg: Message) void {
    self.message_mutex.lock();
    defer self.message_mutex.unlock();
    self.messages.push(msg) catch return;
    self.message_count.post();
}

const MsgQueue = struct {
    buffer: [1024]Message = undefined,
    read_idx: usize = 0,
    write_idx: usize = 0,
    full: bool = false,

    fn push(self: *MsgQueue, msg: Message) !void {
        if (self.full)
            return error.OutOfMemory;

        self.buffer[self.write_idx] = msg;
        self.write_idx = (self.write_idx + 1) % 1024;

        if (self.read_idx == self.write_idx)
            self.full = true;
    }

    fn pop(self: *MsgQueue) ?Message {
        if (self.read_idx == self.write_idx and !self.full)
            return null;

        const val = self.buffer[self.read_idx];
        self.read_idx = (self.read_idx + 1) % 1024;

        self.full = false;
        return val;
    }
};
