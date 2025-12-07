const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day03.txt");

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
    const results = try day03(data);
    print("Answer is {}\n", .{results});
}

fn day03(input: []const u8) !struct { stage1: usize, stage2: usize } {
    var lineIterator = tokenizeSeq(u8, input, "\n");

    var sumStage1: usize = 0;
    var sumStage2: usize = 0;
    while (lineIterator.next()) |line| {
        sumStage1 += computeJoltage(line, 2);
        sumStage2 += computeJoltage(line, 12);
    }

    return .{ .stage1 = sumStage1, .stage2 = sumStage2 };
}

fn computeJoltage(battery: []const u8, comptime count: usize) usize {
    var cells = [_]usize{0} ** count;

    // print("\n", .{});
    outer: for (battery, 0..battery.len) |cellIn, i| {
        const cell = cellIn - '0';

        // print("{}: cell={}\n", .{ i, cell });
        for (0..count) |cellId| {
            if (i < battery.len + 1 - (count - cellId) and cell > cells[cellId]) {
                // print("  Setting cellId {} to {}\n", .{ cellId, cell });
                cells[cellId] = cell;
                for (cellId + 1..count) |z| {
                    cells[z] = 0;
                }
                continue :outer;
            }
        }
    }

    var sum: usize = 0;
    for (0..count) |i| {
        sum = sum * 10 + cells[i];
    }
    return sum;
}

test "compute joltage" {
    try expectEqual(98, computeJoltage("987654321111111", 2));
    try expectEqual(89, computeJoltage("811111111111119", 2));
    try expectEqual(78, computeJoltage("234234234234278", 2));
    try expectEqual(92, computeJoltage("818181911112111", 2));

    try expectEqual(987654321111, computeJoltage("987654321111111", 12));
    try expectEqual(811111111119, computeJoltage("811111111111119", 12));
    try expectEqual(434234234278, computeJoltage("234234234234278", 12));
    try expectEqual(888911112111, computeJoltage("818181911112111", 12));
}
