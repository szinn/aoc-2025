const std = @import("std");

const Allocator = std.mem.Allocator;
const HashMap = std.AutoArrayHashMapUnmanaged;
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

const data = @embedFile("data/day12.txt");
const sampleData =
    \\
;

// pub fn main() !void {
//     var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
//     defer assert(debugAllocator.deinit() == .ok);
//
//     const result = try day12(debugAllocator.allocator(), data);
//
//     print("Result = {}\n", .{result});
// }
//
// fn day12(allocator: Allocator, input: []const u8) !struct {} {
//     var arenaAllocator: std.heap.ArenaAllocator = .init(allocator);
//     defer arenaAllocator.deinit();
//     const arena = arenaAllocator.allocator();
//
//     return .{};
// }
//
// test "Sample data" {
//     const allocator = std.testing.allocator;
//
//     expectEqual(.{}, try day12(allocator, sampleData));
// }

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
