const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day01.txt");
const data_sample =
    \\L68
    \\L30
    \\R48
    \\L5
    \\R60
    \\L55
    \\L1
    \\L99
    \\R14
    \\L82
;

// Useful stdlib functions
const tokenizeAny = std.mem.tokenizeAny;
const tokenizeSeq = std.mem.tokenizeSequence;
const tokenizeSca = std.mem.tokenizeScalar;
const splitAny = std.mem.splitAny;
const splitSeq = std.mem.splitSequence;
const splitSca = std.mem.splitScalar;
const indexOf = std.mem.indexOfScalar;
const indexOfAny = std.mem.indexOfAny;
const indexOfStr = std.mem.indexOfPosLinear;
const lastIndexOf = std.mem.lastIndexOfScalar;
const lastIndexOfAny = std.mem.lastIndexOfAny;
const lastIndexOfStr = std.mem.lastIndexOfLinear;
const trim = std.mem.trim;
const sliceMin = std.mem.min;
const sliceMax = std.mem.max;

const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;

const print = std.debug.print;
const assert = std.debug.assert;

const sort = std.sort.block;
const asc = std.sort.asc;
const desc = std.sort.desc;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn main() !void {
    const results = try day01(data);
    print("Answer is {}", .{results});
}

fn day01(input: []const u8) !struct { stage1: usize, stage2: usize } {
    var line_iterator = tokenizeSeq(u8, input, "\n");

    var dial: isize = 50;
    var counter_stage1: usize = 0;
    var counter_stage2: usize = 0;

    while (line_iterator.next()) |line| {
        const clicks = switch (line[0]) {
            'L' => -try std.fmt.parseInt(isize, line[1..], 10),
            'R' => try std.fmt.parseInt(isize, line[1..], 10),
            else => return error.InvalidCharacter,
        };
        counter_stage2 += @abs(@divFloor(dial + clicks, 100));
        if (dial == 0 and clicks < 0) {
            counter_stage2 -= 1;
        }
        dial = @mod(dial + clicks, 100);
        if (dial == 0) {
            counter_stage1 += 1;
        }
        if (dial == 0 and clicks < 0) {
            counter_stage2 += 1;
        }
    }

    return .{ .stage1 = counter_stage1, .stage2 = counter_stage2 };
}

test "example data" {
    const results = try day01(data_sample[0..]);

    try expectEqual(3, results.stage1);
    try expectEqual(6, results.stage2);
}

test "big rotation" {
    var results = try day01("R1000");
    try expectEqual(0, results.stage1);
    try expectEqual(10, results.stage2);

    results = try day01("R1050");
    try expectEqual(1, results.stage1);
    try expectEqual(11, results.stage2);

    results = try day01("L50");
    try expectEqual(1, results.stage1);
    try expectEqual(1, results.stage2);

    results = try day01("L50\nR100\nL50");
    try expectEqual(2, results.stage1);
    try expectEqual(2, results.stage2);

    results = try day01("L50\nR150\nL50");
    try expectEqual(2, results.stage1);
    try expectEqual(3, results.stage2);

    results = try day01("L50\nL150\nL50");
    try expectEqual(2, results.stage1);
    try expectEqual(3, results.stage2);
}
