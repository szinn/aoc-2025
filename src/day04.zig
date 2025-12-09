const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.array_list.Managed;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day04.txt");
const dataSample =
    \\..@@.@@@@.
    \\@@@.@.@.@@
    \\@@@@@.@.@@
    \\@.@@@@..@.
    \\@@.@@@@.@@
    \\.@@@@@@@.@
    \\.@.@.@.@@@
    \\@.@@@.@@@@
    \\.@@@@@@@@.
    \\@.@.@@@.@.
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

const Cell = enum(u8) { OOB = 'x', EMPTY = '.', ROLL = '@' };
const Grid = List([]Cell);

pub fn main() !void {
    const results = try day04(data);

    print("Answer = {}", .{results});
}

fn day04(input: []const u8) !struct { usize, usize } {
    var grid: Grid = .init(gpa);
    defer {
        for (grid.items) |row| gpa.free(row);
        grid.deinit();
    }

    try loadGrid(input, &grid);

    var removeable: List([2]i32) = .init(gpa);
    defer {
        removeable.deinit();
    }

    try getRemoveable(&grid, &removeable);
    const stage1 = removeable.items.len;

    var stage2: usize = 0;

    while (removeable.items.len > 0) {
        while (removeable.pop()) |cell| {
            const row, const column = cell;
            grid.items[@intCast(row)][@intCast(column)] = Cell.EMPTY;
            stage2 += 1;
        }
        try getRemoveable(&grid, &removeable);
    }

    return .{ stage1, stage2 };
}

fn getRemoveable(grid: *Grid, removeable: *List([2]i32)) !void {
    for (0..grid.items.len) |row| {
        for (0..grid.items[row].len) |column| {
            if (isRemovable(grid, @intCast(row), @intCast(column))) {
                try removeable.append(.{ @intCast(row), @intCast(column) });
            }
        }
    }
}

fn loadGrid(input: []const u8, grid: *Grid) !void {
    var lineIterator = tokenizeSeq(u8, input, "\n");
    while (lineIterator.next()) |line| {
        if (line.len == 0) continue;

        const row = try gpa.alloc(Cell, line.len);
        std.mem.copyForwards(Cell, row, @ptrCast(line));
        try grid.append(row);
    }
}

fn isRemovable(grid: *Grid, row: i32, column: i32) bool {
    if (getContents(grid, row, column) != Cell.ROLL) return false;

    var rolls: usize = 0;
    for (neighbours(row, column)) |rc| {
        if (getContents(grid, rc[0], rc[1]) == Cell.ROLL) {
            rolls += 1;
        }
    }

    return rolls < 4;
}

fn getContents(grid: *Grid, row: i32, column: i32) Cell {
    if (row < 0 or row >= grid.items.len) return Cell.OOB;
    if (column < 0 or column >= grid.items[0].len) return Cell.OOB;

    return grid.items[@intCast(row)][@intCast(column)];
}

fn neighbours(row: i32, column: i32) [8]struct { i32, i32 } {
    return .{
        .{ row - 1, column - 1 },
        .{ row - 1, column },
        .{ row - 1, column + 1 },
        .{ row, column - 1 },
        .{ row, column + 1 },
        .{ row + 1, column - 1 },
        .{ row + 1, column },
        .{ row + 1, column + 1 },
    };
}

test "Sample data" {
    try expectEqual(.{ 13, 43 }, try day04(dataSample));
}
