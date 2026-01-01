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

const data = @embedFile("data/day10.txt");
const sampleData =
    \\[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
    \\[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}
    \\[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}
;

const MAX_LIGHTS = 16;
const MAX_BUTTONS = 16;

const Machine = struct {
    lightCount: usize,
    targetLights: usize,
    buttons: []u16,
    joltages: []usize,

    fn init(allocator: Allocator, lightCount: usize, targetLights: usize, buttons: []u16, joltages: []usize) !Machine {
        const buttonsCopy = try allocator.alloc(u16, buttons.len);
        const joltagesCopy = try allocator.alloc(usize, joltages.len);

        std.mem.copyForwards(u16, buttonsCopy, buttons);
        std.mem.copyForwards(usize, joltagesCopy, joltages);

        return .{
            .lightCount = lightCount,
            .targetLights = targetLights,
            .buttons = buttonsCopy,
            .joltages = joltagesCopy,
        };
    }
};

pub fn main() !void {
    var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
    defer assert(debugAllocator.deinit() == .ok);

    const result = try day10(debugAllocator.allocator(), data);

    print("Result = {}\n", .{result});
}

fn day10(allocator: Allocator, input: []const u8) !struct { usize, usize } {
    var arenaAllocator: std.heap.ArenaAllocator = .init(allocator);
    defer arenaAllocator.deinit();
    const arena = arenaAllocator.allocator();

    const machines: List(*Machine) = try loadMachines(arena, input);

    var sumStage1: usize = 0;
    var sumStage2: usize = 0;
    for (machines.items) |machine| {
        // print("Solving machine: {any}\n", .{machine});
        sumStage1 += solveStage1(machine);
        sumStage2 += try solveStage2(allocator, machine);
    }

    return .{ sumStage1, sumStage2 };
}

fn solveStage1(machine: *const Machine) usize {
    const buttonCombinations = @shlExact(@as(u16, 1), @intCast(machine.buttons.len));
    var minButtons: usize = MAX_BUTTONS;

    // print("  button count: {}, combinations: {}\n", .{ machine.buttons.len, buttonCombinations });
    for (0..buttonCombinations) |combination| {
        var lights: usize = 0;
        var mask: usize = 1;
        var buttonCount: usize = 0;

        // print("  combination: {}\n", .{combination});
        for (0..MAX_LIGHTS, 0..) |_, button| {
            if (combination & mask != 0) {
                lights ^= machine.buttons[button];
                // print("    Flipping button {} lights={}\n", .{ button, lights });
                buttonCount += 1;
            }
            mask *= 2;
        }

        if (lights == machine.targetLights and buttonCount < minButtons) {
            // print("  combination {} has {} button presses\n", .{ combination, buttonCount });
            minButtons = buttonCount;
        }
    }

    return minButtons;
}

fn solveStage2(allocator: Allocator, machine: *const Machine) !usize {
    const buttonCount = machine.buttons.len;
    var coeffBuffer: [MAX_BUTTONS * MAX_LIGHTS]usize = @splat(0);
    var eqnBuffer: [MAX_LIGHTS][]usize = undefined;
    var resultsBuffer: [MAX_LIGHTS]usize = @splat(0);

    for (0..machine.lightCount) |i| {
        eqnBuffer[i] = coeffBuffer[i * buttonCount .. (i + 1) * buttonCount];
        resultsBuffer[i] = machine.joltages[i];
    }
    for (0..machine.buttons.len) |button| {
        var mask: usize = 1;

        for (0..machine.lightCount) |light| {
            if (machine.buttons[button] & mask != 0) {
                eqnBuffer[light][button] = 1;
            }
            mask *= 2;
        }
    }

    const result = try solveLinearInteger(allocator, eqnBuffer[0..machine.lightCount], resultsBuffer[0..machine.lightCount], machine.lightCount, buttonCount);
    // print("  Solution: {any}\n", .{result});
    defer if (result.feasible) allocator.free(result.solution);

    if (!result.feasible) return 0;

    return result.totalSum;
}

const LinearResult = struct {
    feasible: bool,
    solution: []usize,
    totalSum: usize,
};

fn solveLinearInteger(
    allocator: Allocator,
    coefficients: []const []const usize,
    results: []const usize,
    numEquations: usize,
    numVariables: usize,
) !LinearResult {
    // Use Gaussian elimination + bounded enumeration approach
    return try solveGaussianElimination(allocator, coefficients, results, numEquations, numVariables);
}

fn solveGaussianElimination(
    allocator: Allocator,
    coefficients: []const []const usize,
    results: []const usize,
    numEquations: usize,
    numVariables: usize,
) !LinearResult {
    const m = numEquations;
    const n = numVariables;

    // Convert to mutable working arrays (using i32 for signed arithmetic during elimination)
    var equations = try allocator.alloc([]i32, m);
    defer {
        for (equations) |row| allocator.free(row);
        allocator.free(equations);
    }

    var rhs = try allocator.alloc(i32, m);
    defer allocator.free(rhs);

    for (0..m) |i| {
        equations[i] = try allocator.alloc(i32, n);
        for (0..n) |j| {
            equations[i][j] = @intCast(coefficients[i][j]);
        }
        rhs[i] = @intCast(results[i]);
    }

    // Find constraint bounds for each variable
    var constraints = try allocator.alloc(i32, n);
    defer allocator.free(constraints);

    for (0..n) |j| {
        constraints[j] = std.math.maxInt(i32);
        for (0..m) |i| {
            if (equations[i][j] > 0 and rhs[i] < constraints[j]) {
                constraints[j] = rhs[i];
            }
        }
    }

    // Gaussian elimination to find rank (number of dependent variables)
    const bound = gaussianReduce(equations, rhs, constraints, m, n);

    // Enumerate over free variables (those from bound to n)
    var numCombinations: usize = 1;
    for (bound..n) |i| {
        numCombinations *= @intCast(constraints[i] + 1);
    }

    var bestSolution = try allocator.alloc(usize, n);
    var bestSum: usize = std.math.maxInt(usize);
    var foundFeasible = false;

    var combo: usize = 0;
    while (combo < numCombinations) : (combo += 1) {
        var solution = try allocator.alloc(i32, n);
        defer allocator.free(solution);

        // Initialize free variables from combination index
        var idx: i32 = @intCast(combo);
        for (bound..n) |i| {
            solution[i] = @mod(idx, constraints[i] + 1);
            idx = @divFloor(idx, constraints[i] + 1);
        }

        // Back-substitute to find dependent variables
        if (backSubstitute(equations, rhs, solution, bound)) {
            // Verify all values are non-negative
            var allNonNegative = true;
            for (solution) |val| {
                if (val < 0) {
                    allNonNegative = false;
                    break;
                }
            }

            if (allNonNegative) {
                var sum: usize = 0;
                for (solution) |val| {
                    sum += @intCast(val);
                }

                if (sum < bestSum) {
                    bestSum = sum;
                    for (0..n) |i| {
                        bestSolution[i] = @intCast(solution[i]);
                    }
                    foundFeasible = true;
                }
            }
        }
    }

    return LinearResult{
        .feasible = foundFeasible,
        .solution = bestSolution,
        .totalSum = if (foundFeasible) bestSum else 0,
    };
}

fn gaussianReduce(
    equations: [][]i32,
    rhs: []i32,
    constraints: []i32,
    m: usize,
    n: usize,
) usize {
    var skipped: usize = 0;
    var bound: usize = 0;

    for (0..@min(n, m)) |i| {
        // Find pivot (row with non-zero coefficient in column i)
        const pivot = blk: {
            while (true) {
                const p = for (equations[i..], i..) |row, j| {
                    if (row[i] != 0) break j;
                } else null;

                if (p) |piv| break :blk piv;

                // No pivot found, swap columns
                skipped += 1;
                if (i >= n - skipped) return bound;

                swapColumns(equations, constraints, i, n - skipped);
            }
        };

        bound += 1;

        // Swap rows if needed
        if (i != pivot) {
            std.mem.swap([]i32, &equations[i], &equations[pivot]);
            std.mem.swap(i32, &rhs[i], &rhs[pivot]);
        }

        // Eliminate column i in rows below
        for (equations[i + 1 ..], rhs[i + 1 ..]) |*row, *r| {
            if (row.*[i] != 0) {
                subtractRows(equations[i], rhs[i], row.*, r, i);
            }
        }
    }

    return bound;
}

fn swapColumns(equations: [][]i32, constraints: []i32, i: usize, j: usize) void {
    std.mem.swap(i32, &constraints[i], &constraints[j]);
    for (equations) |row| {
        std.mem.swap(i32, &row[i], &row[j]);
    }
}

fn subtractRows(upper: []i32, upperRhs: i32, lower: []i32, lowerRhs: *i32, pivot: usize) void {
    const gcd: i32 = @intCast(std.math.gcd(@abs(upper[pivot]), @abs(lower[pivot])));
    const a = @divExact(upper[pivot], gcd);
    const b = @divExact(lower[pivot], gcd);

    lowerRhs.* *= a;
    lowerRhs.* -= upperRhs * b;

    for (lower, upper) |*l, u| {
        l.* *= a;
        l.* -= u * b;
    }
}

fn backSubstitute(equations: []const []const i32, rhs: []const i32, solution: []i32, bound: usize) bool {
    var i = bound;
    while (i > 0) {
        i -= 1;

        var val = rhs[i];
        for (i + 1..solution.len) |j| {
            val -= solution[j] * equations[i][j];
        }

        if (equations[i][i] == 0 or @rem(val, equations[i][i]) != 0) {
            return false;
        }

        solution[i] = @divExact(val, equations[i][i]);
        if (solution[i] < 0) {
            return false;
        }
    }

    return true;
}

const BnBNode = struct {
    partial: []?usize, // null means not yet fixed
    lowerBound: usize,
};

fn solveBranchAndBound(
    allocator: Allocator,
    coefficients: []const []const usize,
    results: []const usize,
    numEquations: usize,
    numVariables: usize,
) !LinearResult {
    const n = numVariables;
    const m = numEquations;

    // Start with best solution from heuristics
    const bestSolution = try allocator.alloc(usize, n);
    var bestSum: usize = std.math.maxInt(usize);
    var foundFeasible = false;

    // Try greedy first
    const greedyResult = try solveGreedy(allocator, coefficients, results, m, n);
    if (greedyResult.feasible) {
        @memcpy(bestSolution, greedyResult.solution);
        bestSum = greedyResult.totalSum;
        foundFeasible = true;
    }
    allocator.free(greedyResult.solution);

    // Try simplex relaxation
    const simplexResult = try solveSimplexRelaxation(allocator, coefficients, results, m, n);
    if (simplexResult.feasible and simplexResult.totalSum < bestSum) {
        @memcpy(bestSolution, simplexResult.solution);
        bestSum = simplexResult.totalSum;
        foundFeasible = true;
    }
    allocator.free(simplexResult.solution);

    // Try to improve with limited search (or find initial solution if heuristics failed)
    const maxNodes: usize = 1000000; // Increased limit
    var nodesExplored: usize = 0;

    const partial = try allocator.alloc(?usize, n);
    defer allocator.free(partial);
    @memset(partial, null);

    try branchAndBoundRecursive(
        allocator,
        coefficients,
        results,
        m,
        n,
        partial,
        0,
        bestSolution,
        &bestSum,
        &nodesExplored,
        maxNodes,
    );

    return LinearResult{
        .feasible = bestSum != std.math.maxInt(usize),
        .solution = bestSolution,
        .totalSum = if (bestSum != std.math.maxInt(usize)) bestSum else 0,
    };
}

fn branchAndBoundRecursive(
    allocator: Allocator,
    coefficients: []const []const usize,
    results: []const usize,
    m: usize,
    n: usize,
    partial: []?usize,
    depth: usize,
    bestSolution: []usize,
    bestSum: *usize,
    nodesExplored: *usize,
    maxNodes: usize,
) !void {
    if (nodesExplored.* >= maxNodes) return;
    nodesExplored.* += 1;

    // Check if we have a complete solution
    if (depth == n) {
        var solution = try allocator.alloc(usize, n);
        defer allocator.free(solution);

        for (0..n) |i| {
            solution[i] = partial[i] orelse 0;
        }

        // Verify solution
        var feasible = true;
        for (0..m) |i| {
            var sum: usize = 0;
            for (0..n) |j| {
                sum += coefficients[i][j] * solution[j];
            }
            if (sum != results[i]) {
                feasible = false;
                break;
            }
        }

        if (feasible) {
            var totalSum: usize = 0;
            for (solution) |val| {
                totalSum += val;
            }

            if (totalSum < bestSum.*) {
                bestSum.* = totalSum;
                @memcpy(bestSolution, solution);
            }
        }
        return;
    }

    // Calculate lower bound with current partial assignment
    var currentSum: usize = 0;
    for (0..depth) |i| {
        currentSum += partial[i] orelse 0;
    }

    // Prune if lower bound exceeds best
    if (currentSum >= bestSum.*) return;

    // Calculate remaining requirements for each equation
    var minRemaining = try allocator.alloc(usize, m);
    defer allocator.free(minRemaining);
    @memcpy(minRemaining, results);

    for (0..depth) |j| {
        const val = partial[j] orelse 0;
        for (0..m) |i| {
            const contrib = coefficients[i][j] * val;
            if (minRemaining[i] >= contrib) {
                minRemaining[i] -= contrib;
            }
        }
    }

    // Try different values for current variable
    const maxValue = blk: {
        var maxVal: usize = 0;
        for (0..m) |i| {
            if (coefficients[i][depth] == 1 and minRemaining[i] > maxVal) {
                maxVal = minRemaining[i];
            }
        }
        break :blk if (maxVal > 100) 100 else maxVal; // Limit max value
    };

    // Try values from 0 up to maxValue
    var value: usize = 0;
    while (value <= maxValue) : (value += 1) {
        partial[depth] = value;

        try branchAndBoundRecursive(
            allocator,
            coefficients,
            results,
            m,
            n,
            partial,
            depth + 1,
            bestSolution,
            bestSum,
            nodesExplored,
            maxNodes,
        );

        partial[depth] = null;

        // Early termination if we've found a good solution
        if (nodesExplored.* >= maxNodes) break;
    }
}

fn solveGreedy(
    allocator: Allocator,
    coefficients: []const []const usize,
    results: []const usize,
    numEquations: usize,
    numVariables: usize,
) !LinearResult {
    // Greedy heuristic: iteratively assign minimum values to satisfy constraints
    const n = numVariables;
    const m = numEquations;

    var solution = try allocator.alloc(usize, n);
    @memset(solution, 0);

    var remaining = try allocator.alloc(usize, m);
    defer allocator.free(remaining);
    @memcpy(remaining, results);

    // Process variables in order, setting them to satisfy remaining constraints
    var changed = true;
    while (changed) {
        changed = false;

        for (0..n) |j| {
            // Find minimum value needed for variable j
            var minNeeded: usize = 0;

            for (0..m) |i| {
                if (coefficients[i][j] == 0) continue;

                // Count how many other variables can contribute to equation i
                var otherVars: usize = 0;
                for (0..n) |k| {
                    if (k != j and coefficients[i][k] == 1) {
                        otherVars += 1;
                    }
                }

                // If this is the only variable left, we must satisfy the entire remainder
                if (otherVars == 0 and remaining[i] > minNeeded) {
                    minNeeded = remaining[i];
                }
            }

            if (minNeeded > solution[j]) {
                // Update solution and remaining values
                const delta = minNeeded - solution[j];
                solution[j] = minNeeded;
                changed = true;

                for (0..m) |i| {
                    if (coefficients[i][j] == 1) {
                        if (remaining[i] >= delta) {
                            remaining[i] -= delta;
                        }
                    }
                }
            }
        }
    }

    // Verify solution
    var feasible = true;
    for (0..m) |i| {
        var sum: usize = 0;
        for (0..n) |j| {
            sum += coefficients[i][j] * solution[j];
        }
        if (sum != results[i]) {
            feasible = false;
            break;
        }
    }

    var totalSum: usize = 0;
    for (solution) |val| {
        totalSum += val;
    }

    return LinearResult{
        .feasible = feasible,
        .solution = solution,
        .totalSum = totalSum,
    };
}

fn solveSimplexRelaxation(
    allocator: Allocator,
    coefficients: []const []const usize,
    results: []const usize,
    numEquations: usize,
    numVariables: usize,
) !LinearResult {
    // Two-phase simplex method for equality constraints
    const n = numVariables;
    const m = numEquations;

    const tableauCols = n + m + 1;
    const tableauRows = m + 1;

    var tableau = try allocator.alloc([]f64, tableauRows);
    defer {
        for (tableau) |row| allocator.free(row);
        allocator.free(tableau);
    }

    for (0..tableauRows) |i| {
        tableau[i] = try allocator.alloc(f64, tableauCols);
        @memset(tableau[i], 0.0);
    }

    // Set up constraints
    for (0..m) |i| {
        for (0..n) |j| {
            tableau[i][j] = @floatFromInt(coefficients[i][j]);
        }
        tableau[i][n + i] = 1.0;
        tableau[i][tableauCols - 1] = @floatFromInt(results[i]);
    }

    // Phase 1 objective
    for (0..m) |i| {
        tableau[m][n + i] = 1.0;
    }

    for (0..m) |i| {
        for (0..tableauCols) |j| {
            tableau[m][j] -= tableau[i][j];
        }
    }

    if (!simplexSolve(tableau, m, n + m)) {
        const emptySlice = try allocator.alloc(usize, 0);
        return LinearResult{
            .feasible = false,
            .solution = emptySlice,
            .totalSum = 0,
        };
    }

    if (@abs(tableau[m][tableauCols - 1]) > 0.001) {
        const emptySlice = try allocator.alloc(usize, 0);
        return LinearResult{
            .feasible = false,
            .solution = emptySlice,
            .totalSum = 0,
        };
    }

    // Phase 2
    @memset(tableau[m], 0.0);
    for (0..n) |j| {
        tableau[m][j] = 1.0;
    }

    for (0..m) |i| {
        for (0..n) |j| {
            if (@abs(tableau[i][j] - 1.0) < 0.0001) {
                var isBasic = true;
                for (0..m) |k| {
                    if (k != i and @abs(tableau[k][j]) > 0.0001) {
                        isBasic = false;
                        break;
                    }
                }
                if (isBasic and tableau[m][j] != 0.0) {
                    const factor = tableau[m][j];
                    for (0..tableauCols) |col| {
                        tableau[m][col] -= factor * tableau[i][col];
                    }
                }
            }
        }
    }

    _ = simplexSolve(tableau, m, n);

    // Extract continuous solution first
    var floatSolution = try allocator.alloc(f64, n);
    defer allocator.free(floatSolution);
    @memset(floatSolution, 0.0);

    for (0..n) |j| {
        for (0..m) |i| {
            if (@abs(tableau[i][j] - 1.0) < 0.0001) {
                var isBasic = true;
                for (0..m) |k| {
                    if (k != i and @abs(tableau[k][j]) > 0.0001) {
                        isBasic = false;
                        break;
                    }
                }
                if (isBasic) {
                    floatSolution[j] = tableau[i][tableauCols - 1];
                    break;
                }
            }
        }
    }

    // Find fractional variables
    var fractionalVars = try allocator.alloc(bool, n);
    defer allocator.free(fractionalVars);

    for (0..n) |j| {
        const frac = floatSolution[j] - @floor(floatSolution[j]);
        fractionalVars[j] = frac > 0.01 and frac < 0.99;
    }

    // Try all combinations of floor/ceil for fractional variables (up to limit)
    var fractionalCount: usize = 0;
    for (fractionalVars) |isFrac| {
        if (isFrac) fractionalCount += 1;
    }

    var solution = try allocator.alloc(usize, n);
    const bestSolution = try allocator.alloc(usize, n);
    defer allocator.free(bestSolution);
    var bestSum: usize = std.math.maxInt(usize);
    var foundFeasible = false;

    // Limit combinations to prevent explosion
    const maxCombinations: usize = @min(@shlExact(@as(usize, 1), @min(fractionalCount, 16)), 65536);

    var combo: usize = 0;
    while (combo < maxCombinations) : (combo += 1) {
        var fracIdx: usize = 0;
        for (0..n) |j| {
            if (fractionalVars[j]) {
                const useCeil = (combo & (@as(usize, 1) << @intCast(fracIdx))) != 0;
                solution[j] = if (useCeil)
                    @intFromFloat(@ceil(floatSolution[j]))
                else
                    @intFromFloat(@floor(floatSolution[j]));
                fracIdx += 1;
            } else {
                solution[j] = @intFromFloat(@round(floatSolution[j]));
            }
        }

        // Check if this solution is feasible
        var feasible = true;
        for (0..m) |i| {
            var sum: usize = 0;
            for (0..n) |j| {
                sum += coefficients[i][j] * solution[j];
            }
            if (sum != results[i]) {
                feasible = false;
                break;
            }
        }

        if (feasible) {
            var totalSum: usize = 0;
            for (solution) |val| {
                totalSum += val;
            }

            if (totalSum < bestSum) {
                bestSum = totalSum;
                @memcpy(bestSolution, solution);
                foundFeasible = true;
            }
        }
    }

    if (foundFeasible) {
        @memcpy(solution, bestSolution);
    } else {
        // Fallback to simple rounding
        for (0..n) |j| {
            solution[j] = @intFromFloat(@round(floatSolution[j]));
        }
    }

    const feasible = foundFeasible;
    var totalSum: usize = 0;
    for (solution) |val| {
        totalSum += val;
    }

    return LinearResult{
        .feasible = feasible,
        .solution = solution,
        .totalSum = totalSum,
    };
}

fn simplexSolve(tableau: [][]f64, numRows: usize, numCols: usize) bool {
    const maxIterations = 1000;
    const rhs = tableau[0].len - 1;

    var iteration: usize = 0;
    while (iteration < maxIterations) : (iteration += 1) {
        // Find entering variable (most negative in objective row)
        var pivotCol: ?usize = null;
        var mostNegative: f64 = -0.0001;

        for (0..numCols) |j| {
            if (tableau[numRows][j] < mostNegative) {
                mostNegative = tableau[numRows][j];
                pivotCol = j;
            }
        }

        if (pivotCol == null) return true; // Optimal

        // Find leaving variable (minimum ratio)
        var pivotRow: ?usize = null;
        var minRatio: f64 = std.math.inf(f64);

        for (0..numRows) |i| {
            if (tableau[i][pivotCol.?] > 0.0001) {
                const ratio = tableau[i][rhs] / tableau[i][pivotCol.?];
                if (ratio >= -0.0001 and ratio < minRatio) {
                    minRatio = ratio;
                    pivotRow = i;
                }
            }
        }

        if (pivotRow == null) return false; // Unbounded

        // Pivot
        const pRow = pivotRow.?;
        const pCol = pivotCol.?;
        const pivotElement = tableau[pRow][pCol];

        for (0..tableau[pRow].len) |j| {
            tableau[pRow][j] /= pivotElement;
        }

        for (0..tableau.len) |i| {
            if (i != pRow) {
                const factor = tableau[i][pCol];
                for (0..tableau[i].len) |j| {
                    tableau[i][j] -= factor * tableau[pRow][j];
                }
            }
        }
    }

    return false;
}

fn loadMachines(allocator: Allocator, input: []const u8) !List(*Machine) {
    var machines: List(*Machine) = .init(allocator);

    var lineIterator = splitScalar(u8, input, '\n');
    while (lineIterator.next()) |line| if (line.len > 0) {
        var targetLights: usize = 0;
        var buttons: [MAX_BUTTONS]u16 = @splat(0);
        var joltages: [MAX_LIGHTS]usize = @splat(0);
        var lightCount: usize = 0;
        var buttonCount: usize = 0;
        var joltagesCount: usize = 0;

        var partIterator = splitScalar(u8, line, ' ');
        while (partIterator.next()) |part| {
            switch (part[0]) {
                '[' => {
                    var mask: usize = 1;
                    lightCount = part.len - 2;
                    for (1..lightCount + 1) |i| {
                        if (part[i] == '#') targetLights += mask;
                        mask *= 2;
                    }
                },
                '(' => {
                    var buttonPart = splitScalar(u8, part[1 .. part.len - 1], ',');
                    while (buttonPart.next()) |button| {
                        buttons[buttonCount] |= @shlExact(@as(u16, 1), try parseInt(u4, button, 10));
                    }
                    buttonCount += 1;
                },
                '{' => {
                    var joltagePart = splitScalar(u8, part[1 .. part.len - 1], ',');
                    while (joltagePart.next()) |joltage| {
                        joltages[joltagesCount] = try parseInt(usize, joltage, 10);
                        joltagesCount += 1;
                    }
                },
                else => {},
            }
        }

        assert(lightCount == joltagesCount);

        const machine = try allocator.create(Machine);
        machine.* = try .init(allocator, lightCount, targetLights, buttons[0..buttonCount], joltages[0..joltagesCount]);
        try machines.append(machine);
    };

    return machines;
}

test "Sample data" {
    const allocator = std.testing.allocator;

    try expectEqual(.{ 7, 33 }, try day10(allocator, sampleData));
}

test "Solver" {
    const allocator = std.testing.allocator;

    const eq1 = [_]usize{ 0, 0, 0, 0, 1, 1 };
    const eq2 = [_]usize{ 0, 1, 0, 0, 0, 1 };
    const eq3 = [_]usize{ 0, 0, 1, 1, 1, 0 };
    const eq4 = [_]usize{ 1, 1, 0, 1, 0, 0 };
    const coeff = [_][]const usize{ &eq1, &eq2, &eq3, &eq4 };
    const results = [_]usize{ 3, 5, 4, 7 };

    const result = try solveLinearInteger(allocator, &coeff, &results, coeff.len, coeff[0].len);
    if (result.feasible) allocator.free(result.solution);
    try expectEqual(10, result.totalSum);
}

//[...#...] (0,2,3,6) (0,1,4,6) (1,3,4,5) (1,2,4,6) (0,2,3,4,5) (2,3,6) (1,2) (2,3,4,5,6) {37,24,84,71,44,32,71}
test "Board1" {
    const allocator = std.testing.allocator;

    const eq0 = [_]usize{ 1, 1, 0, 0, 1, 0, 0, 0 };
    const eq1 = [_]usize{ 0, 1, 1, 1, 0, 0, 1, 0 };
    const eq2 = [_]usize{ 1, 0, 0, 1, 1, 1, 1, 1 };
    const eq3 = [_]usize{ 1, 0, 1, 0, 1, 1, 0, 1 };
    const eq4 = [_]usize{ 0, 1, 1, 1, 1, 0, 0, 1 };
    const eq5 = [_]usize{ 0, 0, 1, 0, 1, 0, 0, 1 };
    const eq6 = [_]usize{ 1, 1, 0, 1, 0, 1, 0, 1 };
    const coeff = [_][]const usize{ &eq0, &eq1, &eq2, &eq3, &eq4, &eq5, &eq6 };
    const results = [_]usize{ 37, 24, 84, 71, 44, 32, 71 };

    const result = try solveLinearInteger(allocator, &coeff, &results, coeff.len, coeff[0].len);
    defer allocator.free(result.solution);

    // The solver uses Gaussian elimination to reduce the problem to free variables,
    // then enumerates only over those free variables with back-substitution.
    // This is much faster than exhaustive search and finds the optimal solution.
    try expect(result.feasible);
    try expectEqual(90, result.totalSum);
}

// test "real data" {
//     const allocator = std.testing.allocator;
//
//     try expectEqual(.{ 488, 18771 }, try day10(allocator, data));
// }
