const std = @import("std");

const Allocator = std.mem.Allocator;
const HashMap = std.array_hash_map.AutoArrayHashMap;
const List = std.array_list.Managed;

const print = std.debug.print;
const assert = std.debug.assert;
const splitScalar = std.mem.splitScalar;
const tokenizeSequence = std.mem.tokenizeSequence;
const parseInt = std.fmt.parseInt;
const sort = std.sort.block;
const asc = std.sort.asc;
const desc = std.sort.desc;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const data = @embedFile("data/day12.txt");
const sampleData =
    \\0:
    \\###
    \\##.
    \\##.
    \\
    \\1:
    \\###
    \\##.
    \\.##
    \\
    \\2:
    \\.##
    \\###
    \\##.
    \\
    \\3:
    \\##.
    \\###
    \\##.
    \\
    \\4:
    \\###
    \\#..
    \\###
    \\
    \\5:
    \\###
    \\.#.
    \\###
    \\
    \\4x4: 0 0 0 0 2 0
    \\12x5: 1 0 1 0 2 2
    \\12x5: 1 0 1 0 3 2
;

const Shape = struct {
    shape: [3][3]bool,
    filledCount: usize,

    fn load(shape: *Shape, input: []const u8) !void {
        shape.filledCount = 0;
        var lineIterator = splitScalar(u8, input, '\n');
        _ = lineIterator.next();
        for (0..3) |i| {
            const line = lineIterator.next().?;
            for (0..3) |j| {
                if (line[j] == '#') {
                    shape.shape[i][j] = true;
                    shape.filledCount += 1;
                }
            }
        }
    }

    fn dump(self: Shape) void {
        for (0..3) |i| {
            for (0..3) |j| {
                const char: u8 = if (self.shape[i][j]) '#' else '.';
                print("{c}", .{char});
            }
            print("\n", .{});
        }
    }

    fn equal(self: *Shape, other: *Shape) bool {
        for (0..3) |i| {
            for (0..3) |j| {
                if (self.shape[i][j] != other.shape[i][j]) return false;
            }
        }
        return true;
    }
};

const Present = struct {
    shapes: [6]Shape,

    fn init(allocator: Allocator, shape: Shape) !*Present {
        var present = try allocator.create(Present);

        for (0..6) |i| {
            present.shapes[i] = shape;
        }

        return present;
    }
};

const Grid = struct {
    allocator: Allocator,
    rows: usize,
    columns: usize,
    presents: [6]usize,
    totalPresents: usize,

    fn init(allocator: Allocator, input: []const u8) !*Grid {
        const grid = try allocator.create(Grid);
        grid.* = .{
            .allocator = allocator,
            .rows = 0,
            .columns = 0,
            .presents = undefined,
            .totalPresents = 0,
        };

        var counter: usize = 0;
        var splitter = splitScalar(u8, input, ' ');
        while (splitter.next()) |part| if (part.len > 0) {
            if (counter == 0) {
                const x = std.mem.indexOf(u8, part, "x").?;
                const colon = std.mem.indexOf(u8, part, ":").?;
                grid.rows = try parseInt(usize, part[0..x], 10);
                grid.columns = try parseInt(usize, part[x + 1 .. colon], 10);
            } else {
                const count: usize = try parseInt(u8, part, 10);
                grid.presents[counter - 1] = count;
                grid.totalPresents += count;
            }
            counter += 1;
        };

        return grid;
    }

    fn deinit(self: *Grid) void {
        self.allocator.destroy(self);
    }

    fn noTilingRequired(self: Grid) bool {
        return @divFloor(self.rows, 3) * @divFloor(self.columns, 3) >= self.totalPresents;
    }

    fn cantFit(self: Grid, shapes: []Shape) bool {
        const totalArea = self.rows * self.columns;
        var fillRequired: usize = 0;

        for (self.presents, 0..) |count, shape| {
            fillRequired += count * shapes[shape].filledCount;
        }

        return fillRequired > totalArea;
    }

    fn dump(self: Grid) void {
        print("{}x{}: {} total presents to place  --  ", .{ self.rows, self.columns, self.totalPresents });
        for (0..6) |i| print("{} ", .{self.presents[i]});
    }
};

const Puzzle = struct {
    allocator: Allocator,
    shapes: [6]Shape,
    grids: List(*Grid),

    fn init(allocator: Allocator, input: []const u8) !*Puzzle {
        const puzzle = try allocator.create(Puzzle);
        puzzle.* = .{
            .allocator = allocator,
            .shapes = undefined,
            .grids = .init(allocator),
        };

        var shapeCount: usize = 0;
        var blockIterator = tokenizeSequence(u8, input, "\n\n");
        while (blockIterator.next()) |block| if (block.len > 0) {
            if (block[1] == ':') {
                try Shape.load(&puzzle.shapes[shapeCount], block);
                shapeCount += 1;
            } else {
                var lineIterator = splitScalar(u8, block, '\n');
                while (lineIterator.next()) |line| if (line.len > 0) {
                    const grid = try Grid.init(allocator, line);
                    try puzzle.grids.append(grid);
                };
            }
        };

        return puzzle;
    }

    fn deinit(self: *Puzzle) void {
        for (self.grids.items) |item| item.deinit();
        self.grids.deinit();
        self.allocator.destroy(self);
    }

    fn dump(self: *Puzzle) void {
        for (0..6) |shape| {
            print("{}:\n", .{shape});
            self.shapes[shape].dump();
        }
        print("{}\n", .{self.grids.items.len});

        var maxQueries: usize = 0;
        var mustSolve: usize = 0;
        print("\n", .{});
        for (self.grids.items) |grid| {
            var spots: usize = (grid.rows - 2) * (grid.columns - 2);
            for (grid.presents) |p| if (p > 0) {
                spots *= p * 6;
            };
            grid.dump();
            if (grid.cantFit(&self.shapes)) {
                print("  --  Can't fit", .{});
            } else if (grid.noTilingRequired()) {
                print("  -- No tiling required", .{});
            } else {
                mustSolve += 1;
                maxQueries = @max(maxQueries, spots);
            }
            print("\n", .{});
        }

        print("Max queries: {}\n", .{maxQueries});
        print("Must solve: {}\n", .{mustSolve});
    }
};

pub fn main() !void {
    var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
    defer assert(debugAllocator.deinit() == .ok);

    const result = try day12(debugAllocator.allocator(), data);

    print("Result = {}\n", .{result});
}

fn day12(allocator: Allocator, input: []const u8) !struct { usize } {
    var arenaAllocator: std.heap.ArenaAllocator = .init(allocator);
    defer arenaAllocator.deinit();
    const arena = arenaAllocator.allocator();

    const puzzle = try Puzzle.init(arena, input);

    const countStage1 = try stage1(puzzle);

    defer puzzle.deinit();

    puzzle.dump();

    return .{countStage1};
}

fn stage1(puzzle: *Puzzle) !usize {
    var count: usize = 0;
    var impossible: usize = 0;

    for (puzzle.grids.items) |grid| {
        if (grid.noTilingRequired()) {
            count += 1;
        }
        if (grid.cantFit(&puzzle.shapes)) {
            impossible += 1;
        }
    }

    if (count + impossible == puzzle.grids.items.len) {
        return count;
    }

    assert(false);
    return 0;
}

// test "Sample data" {
//     const allocator = std.testing.allocator;
//
//     try expectEqual(.{0}, try day12(allocator, sampleData));
// }
