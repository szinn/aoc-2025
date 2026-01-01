const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.array_list.Managed;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day05.txt");
const sampleData =
    \\3-5
    \\10-20
    \\10-14
    \\16-20
    \\12-18
    \\
    \\1
    \\5
    \\8
    \\11
    \\17
    \\32
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

const Range = struct { low: usize, high: usize };

pub fn main() !void {
    const results = try day05(data);

    print("Answer = {}", .{results});
}

fn day05(input: []const u8) !struct { usize, usize } {
    var ranges: List(Range) = .init(gpa);
    defer {
        ranges.deinit();
    }

    // print("\n", .{});

    var countStage1: usize = 0;
    var countStage2: usize = 0;

    var lineIterator = splitSeq(u8, input, "\n");
    while (lineIterator.next()) |line| {
        if (line.len == 0) break;
        if (indexOf(u8, line, '-')) |index| {
            const lower = try parseInt(usize, line[0..index], 10);
            const upper = try parseInt(usize, line[index + 1 ..], 10);

            try addRange(&ranges, lower, upper);
        }
    }
    // print("Done ranges\n", .{});
    for (0..ranges.items.len) |i| {
        countStage2 += ranges.items[i].high - ranges.items[i].low + 1;
        // print("{} {}\n", .{ ranges.items[i], ranges.items[i].high - ranges.items[i].low + 1 });
    }

    while (lineIterator.next()) |line| {
        if (line.len == 0) break;
        const item = try parseInt(usize, line, 10);
        // print("item {}\n", .{item});

        for (0..ranges.items.len) |i| {
            if (item >= ranges.items[i].low and item <= ranges.items[i].high) {
                countStage1 += 1;
                break;
            }
        }
    }

    return .{ countStage1, countStage2 };
}

fn addRange(ranges: *List(Range), lo: usize, hi: usize) !void {
    var lower = lo;
    var upper = hi;
    // print("{} - {}\n", .{ lower, upper });
    for (ranges.items) |range| {
        // print("  checking against {}-{} against {}\n", .{ lower, upper, range });
        if (lower <= range.low and upper >= range.high) {
            try addRange(ranges, lower, range.low - 1);
            try addRange(ranges, range.high + 1, upper);
            return;
        }
        if (lower >= range.low and lower <= range.high) {
            lower = range.high + 1;
        }
        if (upper >= range.low and upper <= range.high) {
            upper = range.low - 1;
        }
        // print("  {} - {}\n", .{ lower, upper });
        if (upper < lower) {
            // print("  within ranges\n", .{});
            return;
        }
    }

    // countStage2 += upper - lower + 1;
    const range: Range = .{ .low = lower, .high = upper };
    try ranges.append(range);
    // print("Adding {} with {}\n", .{ range, upper - lower + 1 });
}

fn cmpByLower(_: void, a: Range, b: Range) bool {
    return a.low < b.low;
}

test "Sample data" {
    try expectEqual(.{ 3, 14 }, try day05(sampleData));
}

test "real data" {
    try expectEqual(.{ 758, 343143696885053 }, try day05(data));
}
