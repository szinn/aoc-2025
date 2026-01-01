const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.array_list.Managed;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day07.txt");
const sampleData =
    \\.......S.......
    \\...............
    \\.......^.......
    \\...............
    \\......^.^......
    \\...............
    \\.....^.^.^.....
    \\...............
    \\....^.^...^....
    \\...............
    \\...^.^...^.^...
    \\...............
    \\..^...^.....^..
    \\...............
    \\.^.^.^.^.^...^.
    \\...............
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
    const results = try day07(data);

    print("Answer: {}\n", .{results});
}

fn day07(input: []const u8) !struct { usize, usize } {
    var lines: List([]const u8) = .init(gpa);
    var routeCounts: List([]usize) = .init(gpa);
    var beams: []u8 = undefined;
    var nextBeams: []u8 = undefined;
    var sIndex: usize = undefined;
    defer {
        for (routeCounts.items) |line| gpa.free(line);
        routeCounts.deinit();
        lines.deinit();
        gpa.free(beams);
        gpa.free(nextBeams);
    }

    var countStage1: usize = 0;

    var lineIterator = tokenizeSeq(u8, input, "\n");
    while (lineIterator.next()) |line| {
        if (line.len == 0) continue;
        const routes = try gpa.alloc(usize, line.len);
        for (0..line.len) |i| routes[i] = 0;
        try routeCounts.append(routes);

        try lines.append(line);
        if (lines.items.len == 1) {
            if (indexOf(u8, line, 'S')) |startIndex| {
                sIndex = startIndex;
                beams = try gpa.alloc(u8, line.len);
                nextBeams = try gpa.alloc(u8, line.len);
                @memset(beams[0..line.len], 0);
                beams[startIndex] = 1;
            } else {
                print("No starting index\n", .{});
                break;
            }
        } else {
            @memset(nextBeams[0..line.len], 0);
            for (0..line.len) |i| {
                if (beams[i] == 1) {
                    if (line[i] == '^') {
                        countStage1 += 1;
                        if (i > 0) {
                            nextBeams[i - 1] = 1;
                        }
                        if (i < line.len - 1) {
                            nextBeams[i + 1] = 1;
                        }
                    } else {
                        nextBeams[i] = 1;
                    }
                }
            }
            @memcpy(beams[0 .. line.len - 1], nextBeams[0 .. line.len - 1]);
        }
    }

    var countStage2: usize = 0;
    const lineCount = routeCounts.items.len;
    const columnCount = routeCounts.items[0].len;
    for (0..columnCount) |i| routeCounts.items[lineCount - 1][i] = 1;

    var l: i32 = @intCast(lineCount - 2);

    while (l >= 0) : (l -= 1) {
        const line: usize = @intCast(l);
        for (0..columnCount) |column| {
            switch (lines.items[line][column]) {
                '.', 'S' => routeCounts.items[line][column] = routeCounts.items[line + 1][column],
                '^' => {
                    if (column > 0) {
                        routeCounts.items[line][column] += routeCounts.items[line + 1][column - 1];
                    }
                    if (column < columnCount - 1) {
                        routeCounts.items[line][column] += routeCounts.items[line + 1][column + 1];
                    }
                },
                else => {},
            }
        }
    }
    countStage2 = routeCounts.items[0][sIndex];

    return .{ countStage1, countStage2 };
}

test "Sample data" {
    try expectEqual(.{ 21, 40 }, day07(sampleData));
}

test "real data" {
    try expectEqual(.{ 1667, 62943905501815 }, try day07(data));
}
