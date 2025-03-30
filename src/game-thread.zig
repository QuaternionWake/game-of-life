const std = @import("std");
const Thread = std.Thread;

const Gol = @import("game-of-life.zig");

pub var step = false;
pub var clear = false;
pub var randomize = false;
pub var game_paused = false;
pub var should_end = false;

pub var time_target_ns: u64 = std.time.ns_per_s / 60;

pub var times: [256]u64 = std.mem.zeroes([256]u64);
var time_idx: u8 = 0;

pub fn run(game: Gol) !void {
    var random = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rng = random.random();

    var timer = try std.time.Timer.start();

    while (!should_end) {
        if (game_paused) {
            if (step) {
                game.next();
                step = false;
            }
        } else {
            timer.reset();

            game.next();
            step = false;

            times[time_idx] = timer.read();
            time_idx +%= 1;

            Thread.sleep(time_target_ns -| times[time_idx -% 1]);
        }
        if (clear) {
            game.clear();
            clear = false;
        }
        if (randomize) {
            game.randomize(rng);
            randomize = false;
        }
    }
}
