//
//  CircuitLevelGenerator.swift
//  Prisma
//
//  Algorithmically generates a valid Circuit level for daily play.
//  Strategy (back-solve):
//    1. Pick grid size from seed.
//    2. Place terminal pairs.
//    3. Walk a path from each source to its target using a seeded random walk.
//    4. Fill remaining empty cells.
//    5. Spray NOT gates along paths for added difficulty.
//    6. Compute parPathLength as the total cells used by the optimal paths.
//
//  The algorithm never generates Bridge or Synthesizer gates —
//  those are reserved for hand-crafted levels until the mechanic is validated.
//

import Foundation

// MARK: - Seeded RNG

private struct CircuitSeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }

    mutating func next() -> UInt64 {
        // Xorshift64 — fast, good distribution, deterministic
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Generator

struct CircuitLevelGenerator {

    // MARK: - Public Entry Point

    static func generate(for date: Date = .now) -> CircuitLevel {
        let seed = seedFromDate(date)
        var rng = CircuitSeededRNG(seed: seed)
        return buildLevel(id: -Int(seed % UInt64(Int.max)), seed: Int(seed), using: &rng)
    }

    // MARK: - Core Builder

    private static func buildLevel(id: Int, seed: Int, using rng: inout CircuitSeededRNG) -> CircuitLevel {
        // Pick a size: 5, 6, or 7 — based on seed
        let sizes = [5, 5, 5, 6, 6, 7]
        let size = sizes[Int.random(in: 0..<sizes.count, using: &rng)]

        // Pick number of terminal pairs: 1 or 2 for smaller grids, 2 for larger
        let pairCount = size <= 5 ? Int.random(in: 1...2, using: &rng) : 2

        // Build an empty grid of CircuitCellData
        var cells: [[CircuitCellData]] = Array(
            repeating: Array(repeating: .empty, count: size),
            count: size
        )

        var terminalPairs: [TerminalPair] = []
        var occupiedPositions = Set<GridPosition>()
        var solutionPaths: [[GridPosition]] = []

        // Place terminal pairs and walk paths
        var availableColors: [NeonColor] = NeonColor.allCases.shuffled(using: &rng)
        let signals: [SignalState] = [.active, .inactive]

        for pairIndex in 0..<pairCount {
            guard let color = availableColors.isEmpty ? nil : availableColors.removeFirst() else { break }
            let sourceSignal: SignalState = signals[pairIndex % signals.count]

            // Place source: random unoccupied cell
            guard let sourcePos = randomEmptyPosition(in: cells, size: size, excluding: occupiedPositions, using: &rng),
                  let targetPos = randomEmptyPosition(in: cells, size: size, excluding: occupiedPositions.union([sourcePos]), using: &rng)
            else { continue }

            cells[sourcePos.row][sourcePos.col] = .source(color, sourceSignal)
            cells[targetPos.row][targetPos.col] = .target(color, sourceSignal) // no NOT gate yet
            occupiedPositions.insert(sourcePos)
            occupiedPositions.insert(targetPos)

            terminalPairs.append(TerminalPair(
                source: sourcePos,
                target: targetPos,
                color: color,
                signal: sourceSignal
            ))

            // Walk a path from source to target
            if let path = randomWalk(from: sourcePos, to: targetPos, size: size, avoiding: occupiedPositions, using: &rng) {
                solutionPaths.append(path)
                // Mark interior path cells as occupied (not the terminals)
                for pos in path.dropFirst().dropLast() {
                    occupiedPositions.insert(pos)
                }
            }
        }

        // Insert one NOT gate into a path interior cell if there's room
        if let longestPath = solutionPaths.max(by: { $0.count < $1.count }),
           longestPath.count >= 3 {
            let interiorCells = Array(longestPath.dropFirst().dropLast())
            if let gatePos = interiorCells.randomElement(using: &rng) {
                // Only place NOT gate if cell is genuinely empty (interior)
                if cells[gatePos.row][gatePos.col].kind == .empty {
                    cells[gatePos.row][gatePos.col] = .notGate()
                }
            }
        }

        // Compute par path length (sum of all solution path lengths)
        let parPathLength = solutionPaths.reduce(0) { $0 + $1.count }

        return CircuitLevel(
            id: id,
            size: size,
            parPathLength: parPathLength,
            seed: seed,
            grid: cells,
            terminalPairs: terminalPairs
        )
    }

    // MARK: - Random Empty Position

    private static func randomEmptyPosition(
        in cells: [[CircuitCellData]],
        size: Int,
        excluding: Set<GridPosition>,
        using rng: inout CircuitSeededRNG
    ) -> GridPosition? {
        var candidates: [GridPosition] = []
        for r in 0..<size {
            for c in 0..<size {
                let pos = GridPosition(r, c)
                if case .empty = cells[r][c].kind, !excluding.contains(pos) {
                    candidates.append(pos)
                }
            }
        }
        return candidates.randomElement(using: &rng)
    }

    // MARK: - Random Walk

    /// Attempts a random walk from `start` to `end` using a greedy search with backtracking.
    /// Returns nil if no path is found within the allotted attempts.
    private static func randomWalk(
        from start: GridPosition,
        to end: GridPosition,
        size: Int,
        avoiding occupied: Set<GridPosition>,
        using rng: inout CircuitSeededRNG
    ) -> [GridPosition]? {
        // Simple BFS-guided random walk: use BFS to confirm connectivity, then return BFS path
        var queue: [[GridPosition]] = [[start]]
        var visited: Set<GridPosition> = [start]

        while !queue.isEmpty {
            let path = queue.removeFirst()
            let current = path.last!

            if current == end { return path }

            // Shuffle neighbours for randomness
            var neighbors = adjacentPositions(to: current, size: size)
                .filter { !visited.contains($0) && !occupied.contains($0) }
                .shuffled(using: &rng)

            // Bias toward the target
            neighbors.sort { lhs, rhs in
                manhattanDistance(lhs, end) < manhattanDistance(rhs, end)
            }

            for neighbor in neighbors {
                visited.insert(neighbor)
                queue.append(path + [neighbor])
            }
        }
        return nil
    }

    // MARK: - Geometry Helpers

    private static func adjacentPositions(to pos: GridPosition, size: Int) -> [GridPosition] {
        [(-1, 0), (1, 0), (0, -1), (0, 1)].compactMap { (dr, dc) in
            let r = pos.row + dr, c = pos.col + dc
            guard r >= 0, r < size, c >= 0, c < size else { return nil }
            return GridPosition(r, c)
        }
    }

    private static func manhattanDistance(_ a: GridPosition, _ b: GridPosition) -> Int {
        abs(a.row - b.row) + abs(a.col - b.col)
    }

    // MARK: - Seed

    private static func seedFromDate(_ date: Date) -> UInt64 {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let base = UInt64(c.year ?? 2026) * 10_000
               + UInt64(c.month ?? 1) * 100
               + UInt64(c.day ?? 1)
        // Knuth's multiplicative hash — same technique as other Prisma generators
        return base &* 2_654_435_761 &+ 1_013_904_223
    }
}
