const std = @import("std");

const Allocator = std.mem.Allocator;
const HashMap = std.array_hash_map.AutoArrayHashMap;
const List = std.array_list.Managed;

const print = std.debug.print;
const assert = std.debug.assert;
const splitScalar = std.mem.splitScalar;
const parseInt = std.fmt.parseInt;
const sort = std.sort.block;
const asc = std.sort.asc;
const desc = std.sort.desc;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const data = @embedFile("data/day08.txt");
const sampleData =
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

const Circuit = HashMap(*Point, void);
const Circuits = HashMap(*Circuit, void);
const PointToCircuit = HashMap(usize, *Circuit);

const Pair = struct {
    a: *Point,
    b: *Point,
    distance: isize,

    fn distanceLessThan(_: void, b: Pair, a: Pair) bool {
        return a.distance < b.distance;
    }
};

pub fn main() !void {
    var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
    defer assert(debugAllocator.deinit() == .ok);

    const results = try day08(debugAllocator.allocator(), data, 1000);

    print("Answer: {}\n", .{results});
}

fn day08(allocator: Allocator, input: []const u8, circuitCount: usize) !struct { usize, isize } {
    var arenaAllocator: std.heap.ArenaAllocator = .init(allocator);
    const arena = arenaAllocator.allocator();
    defer arenaAllocator.deinit();

    const points: List(*Point) = try loadPoints(arena, input);
    var pairs = try createPairs(arena, points);

    var circuits: Circuits = .init(arena);
    var pointsToCircuitMap: PointToCircuit = .init(arena);
    for (points.items) |point| {
        const circuit = try arena.create(Circuit);
        circuit.* = .init(arena);
        try circuit.put(point, {});
        try circuits.put(circuit, {});
        try pointsToCircuitMap.put(@intFromPtr(point), circuit);
    }

    for (0..circuitCount) |_| {
        _ = try joinClosestPair(&pairs, &circuits, &pointsToCircuitMap);
    }

    var circuitSizes: List(usize) = .init(arena);
    for (circuits.keys()) |circuit| {
        try circuitSizes.append(circuit.keys().len);
    }
    sort(usize, circuitSizes.items, {}, std.sort.desc(usize));

    var finalPair: ?Pair = null;
    while (circuits.keys().len > 1) {
        finalPair = try joinClosestPair(&pairs, &circuits, &pointsToCircuitMap);
    }

    var stage1: usize = 1;
    for (0..3) |i| stage1 *= circuitSizes.items[i];

    const stage2: isize = if (finalPair) |pair| pair.a.x * pair.b.x else 0;

    return .{ stage1, stage2 };
}

fn loadPoints(allocator: Allocator, input: []const u8) !List(*Point) {
    var points: List(*Point) = .init(allocator);

    var lineIterator = splitScalar(u8, input, '\n');
    while (lineIterator.next()) |line| if (line.len > 0) {
        var parts = splitScalar(u8, line, ',');
        const point = try allocator.create(Point);
        point.* = .{
            .x = try parseInt(isize, parts.next().?, 10),
            .y = try parseInt(isize, parts.next().?, 10),
            .z = try parseInt(isize, parts.next().?, 10),
        };
        try points.append(point);
    };

    return points;
}

fn createPairs(allocator: Allocator, points: List(*Point)) !List(Pair) {
    const pointCount = points.items.len;
    const pairCount = pointCount * (pointCount - 1) / 2;

    var pairs: List(Pair) = try .initCapacity(allocator, pairCount);
    for (0..pointCount) |i| for (i + 1..pointCount) |j| {
        const a = points.items[i];
        const b = points.items[j];
        pairs.appendAssumeCapacity(.{
            .a = a,
            .b = b,
            .distance = a.distance(b),
        });
    };
    sort(Pair, pairs.items, {}, Pair.distanceLessThan);

    return pairs;
}

fn joinClosestPair(pairs: *List(Pair), circuits: *Circuits, pointsToCircuitMap: *PointToCircuit) !?Pair {
    const pair = pairs.pop().?;
    const aCircuit = pointsToCircuitMap.get(@intFromPtr(pair.a)).?;
    const bCircuit = pointsToCircuitMap.get(@intFromPtr(pair.b)).?;

    if (aCircuit == bCircuit) return null;

    try aCircuit.ensureUnusedCapacity(bCircuit.keys().len);
    for (bCircuit.keys()) |point| {
        aCircuit.putAssumeCapacity(point, {});
        pointsToCircuitMap.putAssumeCapacity(@intFromPtr(point), aCircuit);
    }

    _ = circuits.orderedRemove(bCircuit);

    return pair;
}

test "Sample data" {
    const allocator = std.testing.allocator;

    try expectEqual(.{ 40, 25272 }, day08(allocator, sampleData, 10));
}

test "real data" {
    const allocator = std.testing.allocator;

    try expectEqual(.{ 52668, 1474050600 }, try day08(allocator, data, 1000));
}
