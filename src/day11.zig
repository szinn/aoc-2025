const std = @import("std");

const Allocator = std.mem.Allocator;
const HashMap = std.array_hash_map.AutoArrayHashMap;
const StringHashMap = std.array_hash_map.StringArrayHashMap;
const List = std.array_list.Managed;

const print = std.debug.print;
const assert = std.debug.assert;
const splitScalar = std.mem.splitScalar;
const parseInt = std.fmt.parseInt;
const indexOf = std.mem.indexOf;
const sort = std.sort.block;
const asc = std.sort.asc;
const desc = std.sort.desc;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const MAX_OUTPUTS = 24;

const data = @embedFile("data/day11.txt");
const sampleDataStage1 =
    \\aaa: you hhh
    \\you: bbb ccc
    \\bbb: ddd eee
    \\ccc: ddd eee fff
    \\ddd: ggg
    \\eee: out
    \\fff: out
    \\ggg: out
    \\hhh: ccc fff iii
    \\iii: out
;
const sampleDataStage2 =
    \\svr: aaa bbb
    \\aaa: fft
    \\fft: ccc
    \\bbb: tty
    \\tty: ccc
    \\ccc: ddd eee
    \\ddd: hub
    \\hub: fff
    \\eee: dac
    \\dac: fff
    \\fff: ggg hhh
    \\ggg: out
    \\hhh: out
;

const Node = struct {
    label: []const u8,
    outputs: List(*Node),
};

pub fn main() !void {
    var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
    defer assert(debugAllocator.deinit() == .ok);

    const result = try day11(debugAllocator.allocator(), data);

    print("Result = {}\n", .{result});
}

fn day11(allocator: Allocator, input: []const u8) !struct { usize, usize } {
    var arenaAllocator: std.heap.ArenaAllocator = .init(allocator);
    defer arenaAllocator.deinit();
    const arena = arenaAllocator.allocator();

    const nodes = try loadData(arena, input);
    var visitedNodes: HashMap(u64, usize) = .init(arena);

    // for (nodes.keys()) |key| {
    //     if (nodes.get(key)) |node| {
    //         print("{s}: ", .{node.label});
    //         for (node.outputs.items) |output| {
    //             print("{s} ", .{output.label});
    //         }
    //         print("\n", .{});
    //     }
    // }

    // print("Stage 1:\n", .{});
    const countStage1 = try dfs(nodes, &visitedNodes, "you", "out");

    var countStage2: usize = 0;
    // print("Stage 2:\n", .{});
    const svr_fft = try dfs(nodes, &visitedNodes, "svr", "fft");
    const fft_dac = try dfs(nodes, &visitedNodes, "fft", "dac");
    const dac_out = try dfs(nodes, &visitedNodes, "dac", "out");
    const svr_dac = try dfs(nodes, &visitedNodes, "svr", "dac");
    const dac_fft = try dfs(nodes, &visitedNodes, "dac", "fft");
    const fft_out = try dfs(nodes, &visitedNodes, "fft", "out");

    // print("svr-fft: {}\n", .{svr_fft});
    // print("fft-dac: {}\n", .{svr_dac});
    // print("dac-out: {}\n", .{dac_out});
    // print("svr-dac: {}\n", .{svr_dac});
    // print("dac-fft: {}\n", .{dac_fft});
    // print("fft-out: {}\n", .{fft_out});

    countStage2 += svr_fft * fft_dac * dac_out + svr_dac * dac_fft * fft_out;

    return .{ countStage1, countStage2 };
}

fn dfs(nodes: *StringHashMap(*Node), visitedNodes: *HashMap(u64, usize), from: []const u8, target: []const u8) !usize {
    if (nodes.get(from)) |node| {
        return dfsWithCache(node, visitedNodes, target);
    } else {
        return 0;
    }
}

fn dfsWithCache(node: *const Node, visitedNodes: *HashMap(u64, usize), target: []const u8) !usize {
    // print("visiting node {s}\n", .{node.label});
    if (std.mem.eql(u8, node.label, target)) {
        return 1;
    }

    var hashCalc: std.hash.XxHash3 = .init(0);
    hashCalc.update(node.label);
    hashCalc.update(target);
    const hash = hashCalc.final();
    if (visitedNodes.get(hash)) |value| {
        // print("  Already visited: {}\n", .{value});
        return value;
    }

    var count: usize = 0;
    for (node.outputs.items) |child| {
        count += try dfsWithCache(child, visitedNodes, target);
    }

    try visitedNodes.put(hash, count);

    return count;
}

fn loadData(allocator: Allocator, input: []const u8) !*StringHashMap(*Node) {
    const nodes: *StringHashMap(*Node) = try allocator.create(StringHashMap(*Node));
    nodes.* = .init(allocator);

    var lineIterator = splitScalar(u8, input, '\n');
    while (lineIterator.next()) |line| if (line.len > 0) {
        if (indexOf(u8, line, ":")) |index| {
            const label = line[0..index];
            var node: *Node = undefined;
            if (nodes.get(label)) |existingNode| {
                node = existingNode;
            } else {
                node = try allocator.create(Node);
                node.* = .{
                    .label = label,
                    .outputs = .init(allocator),
                };
                try nodes.put(label, node);
            }

            var outputsIterator = splitScalar(u8, line[index + 2 ..], ' ');
            while (outputsIterator.next()) |output| {
                var outputNode: *Node = undefined;
                if (nodes.get(output)) |existingOutput| {
                    outputNode = existingOutput;
                } else {
                    outputNode = try allocator.create(Node);
                    outputNode.* = .{
                        .label = output,
                        .outputs = .init(allocator),
                    };
                    try nodes.put(output, outputNode);
                }
                try node.outputs.append(outputNode);
            }
        }
    };

    return nodes;
}

test "Sample data" {
    const allocator = std.testing.allocator;

    try expectEqual(.{ 5, 0 }, try day11(allocator, sampleDataStage1));
    try expectEqual(.{ 0, 2 }, try day11(allocator, sampleDataStage2));
}

test "real data" {
    const allocator = std.testing.allocator;

    try expectEqual(.{ 791, 520476725037672 }, try day11(allocator, data));
}
