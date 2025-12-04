const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day02.txt");
const data_sample = "11-22,95-115,998-1012,1188511880-1188511890,222220-222224,1698522-1698528,446443-446449,38593856-38593862,565653-565659,824824821-824824827,2121212118-2121212124";

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
    const result = try day02(data);
    print("Answer is {}\n", .{result});
}

fn day02(input: []const u8) !struct { stage1: usize, stage2: usize } {
    var rangeIterator = tokenizeSeq(u8, input, ",");

    var sum_stage1: usize = 0;
    var sum_stage2: usize = 0;
    while (rangeIterator.next()) |range| {
        const trimmedRange = trim(u8, range, "\n");
        if (indexOf(u8, trimmedRange, '-')) |index| {
            const lower = try parseInt(usize, trimmedRange[0..index], 10);
            const upper = try parseInt(usize, trimmedRange[index + 1 ..], 10);

            sum_stage1 += sumInvalidStageIds(lower, upper, isValidStage1Id);
            sum_stage2 += sumInvalidStageIds(lower, upper, isValidStage2Id);
        }
    }

    return .{ .stage1 = sum_stage1, .stage2 = sum_stage2 };
}

fn sumInvalidStageIds(lower: usize, upper: usize, comptime isValidId: fn (usize) bool) usize {
    var sum: usize = 0;

    for (lower..upper + 1) |i| {
        if (!isValidId(i)) {
            sum += i;
        }
    }
    return sum;
}

fn isValidStage1Id(value: usize) bool {
    const len = std.math.log10_int(value) + 1;

    if (len & 1 == 1) {
        return true;
    }

    const mask = std.math.powi(usize, 10, len / 2) catch {
        unreachable;
    };

    return (value / mask) != @mod(value, mask);
}

fn isValidStage2Id(value: usize) bool {
    const len = std.math.log10_int(value) + 1;
    for (1..(len / 2 + 1)) |digitCount| {
        if (@mod(len - digitCount, digitCount) != 0) continue;

        const mask: usize = std.math.powi(usize, 10, digitCount) catch {
            unreachable;
        };
        const digits = @mod(value, mask);
        var sum: usize = 0;
        for (0..(len / digitCount)) |x| {
            const shift: usize = std.math.powi(usize, 10, digitCount * x) catch {
                unreachable;
            };
            sum += digits * shift;
        }
        if (sum == value) return false;
    }

    return true;
}

test "example data" {
    const result = try day02(data_sample);

    try expectEqual(1227775554, result.stage1);
}

test "check valid stage1" {
    try expect(!isValidStage1Id(11));
    try expect(isValidStage1Id(111));
    try expect(isValidStage1Id(12));
    try expect(!isValidStage1Id(1212));
}

test "check valid stage2" {
    try expect(!isValidStage2Id(11));
    try expect(!isValidStage2Id(12341234));
    try expect(isValidStage2Id(123));
    try expect(!isValidStage2Id(12121212));
}
