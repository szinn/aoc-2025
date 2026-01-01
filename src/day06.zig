const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.array_list.Managed;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day06.txt");
const sampleData =
    \\123 328  51 64 
    \\ 45 64  387 23 
    \\  6 98  215 314
    \\*   +   *   +  
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

const Operation = enum {
    UNKNOWN,
    MULTIPLY,
    ADD,
};

const Operator = struct {
    operation: Operation,
    column: usize,
};

pub fn main() !void {
    const results = try day06(data);

    print("Answer: {}\n", .{results});
}

fn day06(input: []const u8) !struct { usize, usize } {
    var lines: List([]const u8) = .init(gpa);
    var operators: List(Operator) = .init(gpa);
    defer {
        lines.deinit();
        operators.deinit();
    }

    var lineIterator = tokenizeSeq(u8, input, "\n");
    while (lineIterator.next()) |line| {
        if (line.len == 0) continue;

        switch (line[0]) {
            '*', '+' => {
                for (line, 0..) |c, i| {
                    switch (c) {
                        '*' => {
                            try operators.append(Operator{ .operation = Operation.MULTIPLY, .column = i });
                        },
                        '+' => {
                            try operators.append(Operator{ .operation = Operation.ADD, .column = i });
                        },
                        else => {},
                    }
                }
                try operators.append(Operator{ .operation = Operation.UNKNOWN, .column = line.len });
            },

            else => {
                try lines.append(line);
            },
        }
    }

    var sumStage1: usize = 0;
    var sumStage2: usize = 0;
    const operatorItems = operators.items;
    for (0..operatorItems.len - 1) |i| {
        const operator = operatorItems[i];
        const startColumn = operator.column;
        const endColumn = operatorItems[i + 1].column;

        // stage1
        var resultStage1: usize = identity(operator.operation);
        for (lines.items) |line| {
            const numberText = std.mem.trim(u8, line[operator.column..endColumn], " ");
            const number = try parseInt(usize, numberText, 10);
            switch (operator.operation) {
                Operation.ADD => resultStage1 += number,
                Operation.MULTIPLY => resultStage1 *= number,
                else => {},
            }
        }
        sumStage1 += resultStage1;

        // stage2
        var result: usize = identity(operator.operation);
        for (startColumn..endColumn) |column| {
            var number: usize = 0;
            var hasDigit: bool = false;
            for (lines.items) |line| {
                const c: u8 = line[column];

                if (c != ' ') {
                    hasDigit = true;
                    number = number * 10 + (c - '0');
                }
            }
            if (hasDigit) {
                switch (operator.operation) {
                    Operation.ADD => result += number,
                    Operation.MULTIPLY => result *= number,
                    else => {},
                }
            }
        }
        sumStage2 += result;
    }

    return .{ sumStage1, sumStage2 };
}

fn identity(operation: Operation) usize {
    return switch (operation) {
        .ADD => 0,
        .MULTIPLY => 1,
        else => 0,
    };
}

test "Sample data" {
    try expectEqual(.{ 4277556, 3263827 }, day06(sampleData));
}

test "real data" {
    try expectEqual(.{ 4449991244405, 9348430857627 }, try day06(data));
}
