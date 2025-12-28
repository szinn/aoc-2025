const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.array_list.Managed;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day08.txt");
const dataSample =
    \\162,817,812
    \\57,618,57
    \\906,360,560
    \\592,479,940
    \\352,342,300
    \\466,668,158
    \\542,29,236
    \\431,825,988
    \\739,650,466
    \\52,470,668
    \\216,146,977
    \\819,987,18
    \\117,168,530
    \\805,96,715
    \\346,949,466
    \\970,615,88
    \\941,993,340
    \\862,61,35
    \\984,92,344
    \\425,690,689
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

const Point = struct {
    x: isize,
    y: isize,
    z: isize,

    fn distance(self: Point, other: *const Point) isize {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return dx * dx + dy * dy + dz * dz;
    }
};

pub fn main() !void {
    const results = try day08(data, 1000);

    print("Answer: {}\n", .{results});
}

fn day08(input: []const u8, circuitCount: usize) !struct { usize, isize } {
    var pointData: List(Point) = .init(gpa);
    defer pointData.deinit();
    try readPoints(&pointData, input);
    const points: []Point = pointData.items;
    const pointCount: usize = points.len;

    var circuitId: []usize = try gpa.alloc(usize, pointCount);
    defer gpa.free(circuitId);
    for (0..pointCount) |i| circuitId[i] = i;

    const circuitCounts: []usize = try gpa.alloc(usize, pointCount);
    defer {
        gpa.free(circuitCounts);
    }
    for (0..pointCount) |i| circuitCounts[i] = 1;

    var connected: List([]bool) = .init(gpa);
    for (0..pointCount) |_| {
        const row: []bool = try gpa.alloc(bool, pointCount);
        for (0..pointCount) |i| row[i] = false;
        try connected.append(row);
    }
    defer {
        for (connected.items) |row| gpa.free(row);
        connected.deinit();
    }

    var countStage1: usize = 1;
    var circuit: usize = 0;
    var stage2Product: isize = undefined;
    while (true) {
        const nextClosest = getNextShortestDistance(pointCount, points, &connected);
        const pointA = nextClosest.pointA;
        const pointB = nextClosest.pointB;
        const distance = nextClosest.distance;

        if (distance == std.math.maxInt(isize)) break;

        // print("Shortest path {} is from {} to {}\n", .{ circuit, points[pointA], points[pointB] });

        connected.items[pointA][pointB] = true;
        if (circuitId[pointA] != circuitId[pointB]) {
            try combineCircuits(pointCount, circuitId, circuitCounts, pointA, pointB);
            stage2Product = points[pointA].x * points[pointB].x;
        }

        if (circuit == circuitCount - 1) {
            var counts: []usize = try gpa.alloc(usize, pointCount);
            defer gpa.free(counts);
            @memcpy(counts, circuitCounts[0..pointCount]);
            sort(usize, counts[0..pointCount], {}, std.sort.desc(usize));

            for (0..3) |i| {
                if (counts[i] != 0) countStage1 *= counts[i];
            }
        }
        if (circuitSetCount(pointCount, circuitCounts) == 1) break;

        circuit += 1;
    }

    return .{ countStage1, stage2Product };
}

fn circuitSetCount(pointCount: usize, circuits: []usize) usize {
    var count: usize = 0;
    for (0..pointCount) |i| {
        if (circuits[i] > 0) count += 1;
    }

    return count;
}

fn getNextShortestDistance(pointCount: usize, points: []Point, connected: *List([]bool)) struct { pointA: usize, pointB: usize, distance: isize } {
    var pointA: usize = undefined;
    var pointB: usize = undefined;
    var distance: isize = std.math.maxInt(isize);

    for (0..pointCount) |i| {
        for (0..pointCount) |j| {
            if (i == j) continue;
            if (connected.items[i][j] or connected.items[j][i]) continue;

            const currentDistance = points[i].distance(&points[j]);

            if (currentDistance < distance) {
                pointA = i;
                pointB = j;
                distance = currentDistance;
            }
        }
    }

    return .{ .pointA = pointA, .pointB = pointB, .distance = distance };
}

fn combineCircuits(pointCount: usize, circuits: []usize, circuitCounts: []usize, pointA: usize, pointB: usize) !void {
    const circuitA = circuits[pointA];
    const circuitB = circuits[pointB];
    if (circuitA == circuitB) return;

    if (circuitA < circuitB) {
        // print("  Moving circuit {} to {} ({} and {})\n", .{ circuitB, circuitA, circuitCounts[circuitB], circuitCounts[circuitA] });
        try moveCircuit(pointCount, circuits, circuitB, circuitA);
        circuitCounts[circuitA] += circuitCounts[circuitB];
        circuitCounts[circuitB] = 0;
    } else {
        // print("  Moving circuit {} to {} ({} and {})\n", .{ circuitA, circuitB, circuitCounts[circuitA], circuitCounts[circuitB] });
        try moveCircuit(pointCount, circuits, circuitA, circuitB);
        circuitCounts[circuitB] += circuitCounts[circuitA];
        circuitCounts[circuitA] = 0;
    }
}

fn moveCircuit(pointCount: usize, circuits: []usize, from: usize, to: usize) !void {
    for (0..pointCount) |i| {
        if (circuits[i] == from) {
            circuits[i] = to;
        }
    }
}

fn readPoints(points: *List(Point), input: []const u8) !void {
    var lineIterator = splitSeq(u8, input, "\n");
    while (lineIterator.next()) |line| {
        if (line.len == 0) break;
        if (indexOf(u8, line, ',')) |yOffset| {
            if (lastIndexOf(u8, line, ',')) |zOffset| {
                const x = try parseInt(isize, line[0..yOffset], 10);
                const y = try parseInt(isize, line[yOffset + 1 .. zOffset], 10);
                const z = try parseInt(isize, line[zOffset + 1 ..], 10);

                try points.append(Point{ .x = x, .y = y, .z = z });
            }
        }
    }
}

test "Sample data" {
    try expectEqual(.{ 40, 25272 }, day08(dataSample, 10));
}
