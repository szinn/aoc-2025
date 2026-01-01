const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day01.txt");
const sampleData =
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
    print("Answer is {}\n", .{results});
}

fn day01(input: []const u8) !struct { usize, usize } {
    var lineIterator = tokenizeSeq(u8, input, "\n");

    var dial: isize = 50;
    var counterStage1: usize = 0;
    var counterStage2: usize = 0;

    while (lineIterator.next()) |line| {
        const clicks = switch (line[0]) {
            'L' => -try parseInt(isize, line[1..], 10),
            'R' => try parseInt(isize, line[1..], 10),
            else => return error.InvalidCharacter,
        };
        counterStage2 += @abs(@divFloor(dial + clicks, 100));
        if (dial == 0 and clicks < 0) {
            counterStage2 -= 1;
        }
        dial = @mod(dial + clicks, 100);
        if (dial == 0) {
            counterStage1 += 1;
        }
        if (dial == 0 and clicks < 0) {
            counterStage2 += 1;
        }
    }

    return .{ counterStage1, counterStage2 };
}

test "example data" {
    try expectEqual(.{ 3, 6 }, try day01(sampleData));
}

test "real data" {
    try expectEqual(.{ 1031, 5831 }, try day01(data));
}
