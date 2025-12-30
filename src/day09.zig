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

const data = @embedFile("data/day09.txt");
const sampleData =
    \\7,1
    \\11,1
    \\11,7
    \\9,7
    \\9,5
    \\2,5
    \\2,3
    \\7,3
;

const Point = struct {
    x: usize,
    y: usize,

    fn area(self: Point, other: *const Point) usize {
        const dx = @max(self.x, other.x) - @min(self.x, other.x);
        const dy = @max(self.y, other.y) - @min(self.y, other.y);

        return (dx + 1) * (dy + 1);
    }
};

const Line = struct {
    a: Point,
    b: Point,

    fn init(a: *Point, b: *Point) Line {
        return .{
            .a = Point{ .x = @min(a.x, b.x), .y = @min(a.y, b.y) },
            .b = Point{ .x = @max(a.x, b.x), .y = @max(a.y, b.y) },
        };
    }

    fn byYThenX(_: void, a: *Line, b: *Line) bool {
        if (a.a.y < b.a.y) return true;
        if (a.a.y > b.a.y) return false;

        return a.a.x < b.a.x;
    }

    fn isHorizontal(self: Line) bool {
        return self.a.y == self.b.y;
    }

    fn isVertical(self: Line) bool {
        return self.a.x == self.b.x;
    }
};

const Area = struct {
    a: Point,
    b: Point,
    area: usize,

    fn init(a: *Point, b: *Point) Area {
        return .{
            .a = Point{ .x = @min(a.x, b.x), .y = @min(a.y, b.y) },
            .b = Point{ .x = @max(a.x, b.x), .y = @max(a.y, b.y) },
            .area = a.area(b),
        };
    }

    fn descendingArea(_: void, a: Area, b: Area) bool {
        return a.area > b.area;
    }
};

pub fn main() !void {
    var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
    defer assert(debugAllocator.deinit() == .ok);
    const result = try day09(debugAllocator.allocator(), data);

    print("Result = {}\n", .{result});
}

fn day09(allocator: Allocator, input: []const u8) !struct { usize, usize } {
    var arenaAllocator: std.heap.ArenaAllocator = .init(allocator);
    defer arenaAllocator.deinit();
    const arena = arenaAllocator.allocator();

    const points: List(*Point) = try loadPoints(arena, input);
    const areas = try createAreas(arena, points);

    const areaStage1 = areas.items[0].area;
    var areaStage2: usize = undefined;

    outer: for (areas.items, 0..) |area, j| {
        for (0..points.items.len - 1) |i| {
            const line: Line = .init(points.items[i], points.items[i + 1]);
            if (line.isHorizontal()) {
                if (line.b.x <= area.a.x or line.a.x >= area.b.x) continue;
                if (line.a.y <= area.a.y or line.a.y >= area.b.y) continue;
                continue :outer;
            }

            if (line.isVertical()) {
                if (line.b.y <= area.a.y or line.a.y >= area.b.y) continue;
                if (line.a.x <= area.a.x or line.a.x >= area.b.x) continue;
                continue :outer;
            }
        }
        print("Stage 2 answer is candidate #{} - {}\n", .{ j, area });
        areaStage2 = area.area;
        break;
    }

    return .{ areaStage1, areaStage2 };
}

fn loadPoints(allocator: Allocator, input: []const u8) !List(*Point) {
    var points: List(*Point) = .init(allocator);

    var lineIterator = splitScalar(u8, input, '\n');
    while (lineIterator.next()) |line| if (line.len > 0) {
        var parts = splitScalar(u8, line, ',');
        const point = try allocator.create(Point);
        point.* = .{
            .x = try parseInt(usize, parts.next().?, 10),
            .y = try parseInt(usize, parts.next().?, 10),
        };
        try points.append(point);
    };
    try points.append(points.items[0]);

    return points;
}

fn createAreas(allocator: Allocator, points: List(*Point)) !List(Area) {
    const pointCount = points.items.len;
    const areaCount = pointCount * (pointCount - 1) / 2;

    var areas: List(Area) = try .initCapacity(allocator, areaCount);
    for (0..pointCount) |i| for (i + 1..pointCount) |j| {
        const a = points.items[i];
        const b = points.items[j];
        areas.appendAssumeCapacity(Area.init(a, b));
    };
    sort(Area, areas.items, {}, Area.descendingArea);

    return areas;
}

test "Sample data" {
    const allocator = std.testing.allocator;

    try expectEqual(.{ 50, 24 }, try day09(allocator, sampleData));
}
