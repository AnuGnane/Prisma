//
//  CargoPuzzleGenerator.swift
//  Prisma
//
//  Algorithmic daily Cargo puzzle generator.
//
//  Strategy (back-solve / region-partition):
//  1. Choose a grid size seeded from the date.
//  2. Flood-fill partition the entire grid into N connected polyomino regions
//     (sizes 2–6 cells each, using a seeded PRNG).
//  3. Each region becomes a puzzle piece — the puzzle is guaranteed solvable
//     because the pieces exactly tile the grid by construction.
//  4. Shuffle piece IDs so the visual order is unpredictable.
//
//  The algorithm is deterministic for a given seed, so the same date always
//  produces the same puzzle, independent of the local JSON level pool.
//
//  IMPORTANT — Set iteration determinism (2026-05-06):
//  Swift `Set` iteration order is randomised per process via the Hasher seed.
//  Earlier versions used `Set<CellCoord>` for the unclaimed/frontier pools and
//  called `randomElement(using:)` on them — same RNG state, different element
//  returned each launch, producing a different puzzle for the same date. The
//  fix is to convert any Set to a deterministically-ordered array (sorted by
//  row, then column) BEFORE drawing from the seeded RNG. Don't reintroduce
//  `Set<CellCoord>.randomElement(using:)` or `Array(set)` in random-pick paths.
//

import Foundation

// MARK: - Seeded RNG (reuses the same LCG as ShiftPuzzleGenerator)

private struct CargoSeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Generator

struct CargoPuzzleGenerator {

    // MARK: - Public Entry Point

    /// Generates a unique daily puzzle seeded from the given date.
    /// Never overlaps with local JSON pool (different code path entirely).
    static func generateDailyPuzzle(for date: Date = .now) -> CargoPuzzle {
        let seed = seedFromDate(date)
        var rng = CargoSeededRNG(seed: seed)
        return generate(seed: seed, rng: &rng)
    }

    // MARK: - Core Generation

    private static func generate(seed: UInt64, rng: inout CargoSeededRNG) -> CargoPuzzle {
        // Choose grid size: 5×5, 5×6, 6×6, or 6×7 — variety across days
        let sizeChoices: [(rows: Int, cols: Int)] = [(5,5), (5,6), (6,6), (6,7), (5,7)]
        let sizeIdx = Int.random(in: 0..<sizeChoices.count, using: &rng)
        let (rows, cols) = sizeChoices[sizeIdx]

        // Build a region map: each cell in the rows×cols grid is assigned a piece-region ID.
        // We grow regions one at a time from random seed cells until every cell is claimed.
        // `unclaimed` is a Set for O(1) contains/remove, but every random pick from it MUST
        // go through `sortedSet(_:)` first to enforce a stable iteration order across runs.
        var regionMap = Array(repeating: Array(repeating: -1, count: cols), count: rows)
        var regionCells: [[CellCoord]] = []   // regionCells[i] = all coords belonging to region i
        var unclaimed: Set<CellCoord> = {
            var s = Set<CellCoord>()
            for r in 0..<rows { for c in 0..<cols { s.insert(CellCoord(r, c)) } }
            return s
        }()

        let targetPieceSizes = choosePieceSizes(gridTotal: rows * cols, using: &rng)

        for targetSize in targetPieceSizes {
            guard !unclaimed.isEmpty else { break }

            let regionId = regionCells.count
            // Pick a deterministic-order start cell. `sortedSet` enforces a
            // stable order so the seeded RNG draws the same element across runs.
            let start = sortedSet(unclaimed).randomElement(using: &rng)!
            var region: [CellCoord] = [start]
            regionMap[start.row][start.col] = regionId
            unclaimed.remove(start)

            // Grow the region by random-frontier expansion. `adjacentUnclaimed`
            // already returns a sorted array, so this pick is deterministic too.
            var frontier = adjacentUnclaimed(to: region, in: &unclaimed, rows: rows, cols: cols)
            while region.count < targetSize, !frontier.isEmpty {
                let pick = frontier.randomElement(using: &rng)!
                region.append(pick)
                regionMap[pick.row][pick.col] = regionId
                unclaimed.remove(pick)
                frontier = adjacentUnclaimed(to: region, in: &unclaimed, rows: rows, cols: cols)
            }

            regionCells.append(region)
        }

        // If any unclaimed cells remain (rounding), merge them into the closest region.
        // Iterate in sorted order so the merge target is consistent across runs.
        for coord in sortedSet(unclaimed) {
            let neighbourId = neighbourRegionId(for: coord, in: regionMap, rows: rows, cols: cols)
            let id = neighbourId ?? (regionCells.count - 1)
            regionMap[coord.row][coord.col] = id
            regionCells[id].append(coord)
        }

        // Build CargoPieces — cells are in absolute grid coords; normalise to relative
        var pieces: [CargoPiece] = []
        var shuffledIds = Array(1...regionCells.count)
        shuffledIds.shuffle(using: &rng)

        for (idx, region) in regionCells.enumerated() {
            let pieceId = shuffledIds[idx]
            let normalised = normaliseToOrigin(region)
            // Store the raw absolute coords as solutionCells so the solution view can
            // reconstruct exactly where this piece sits on the grid.
            let piece = CargoPiece(pieceId: pieceId, baseCells: normalised, solutionCells: region)
            pieces.append(piece)
        }

        // Sort pieces by id so the tray order is consistent
        pieces.sort { $0.id < $1.id }

        // Puzzle ID: negative seed to distinguish from JSON pool IDs (which are 1..100)
        let puzzleId = -Int(seed % UInt64(Int.max))

        return CargoPuzzle(
            id: puzzleId,
            gridRows: rows,
            gridCols: cols,
            blockedCells: [],             // generated puzzles have no blocked cells
            pieces: pieces
        )
    }

    // MARK: - Piece Size Planning

    /// Decides how many pieces of what sizes to grow, summing to exactly `gridTotal`.
    private static func choosePieceSizes(gridTotal: Int, using rng: inout CargoSeededRNG) -> [Int] {
        // Target 4–8 pieces, each 2–7 cells, summing to gridTotal
        var remaining = gridTotal
        var sizes: [Int] = []
        let minSize = 2
        let maxSize = 7

        while remaining > 0 {
            let spaceLeft = remaining - Int(sizes.count + 1) * minSize  // leave room for future pieces
            let upper = min(maxSize, max(minSize, spaceLeft + minSize))
            let size = Int.random(in: minSize...upper, using: &rng)
            let actual = min(size, remaining)
            sizes.append(actual)
            remaining -= actual
        }
        return sizes.shuffled(using: &rng)
    }

    // MARK: - Geometry Helpers

    private static func adjacentUnclaimed(
        to region: [CellCoord],
        in unclaimed: inout Set<CellCoord>,
        rows: Int,
        cols: Int
    ) -> [CellCoord] {
        var frontier = Set<CellCoord>()
        let deltas = [(-1,0),(1,0),(0,-1),(0,1)]
        for coord in region {
            for (dr, dc) in deltas {
                let n = CellCoord(coord.row + dr, coord.col + dc)
                if n.row >= 0, n.row < rows, n.col >= 0, n.col < cols, unclaimed.contains(n) {
                    frontier.insert(n)
                }
            }
        }
        // Always return a sorted array — see "Set iteration determinism" note
        // at the top of the file. `Array(set)` preserves the Set's randomised
        // iteration order and breaks the seeded RNG's determinism.
        return sortedSet(frontier)
    }

    /// Returns the set's elements in a stable order (row, then column).
    /// Use this anywhere a seeded RNG is going to draw from a Set — Swift's
    /// hash randomisation otherwise yields different orderings per process.
    private static func sortedSet(_ set: Set<CellCoord>) -> [CellCoord] {
        set.sorted { lhs, rhs in
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.col < rhs.col
        }
    }

    private static func neighbourRegionId(
        for coord: CellCoord,
        in map: [[Int]],
        rows: Int,
        cols: Int
    ) -> Int? {
        let deltas = [(-1,0),(1,0),(0,-1),(0,1)]
        for (dr, dc) in deltas {
            let nr = coord.row + dr
            let nc = coord.col + dc
            if nr >= 0, nr < rows, nc >= 0, nc < cols {
                let id = map[nr][nc]
                if id >= 0 { return id }
            }
        }
        return nil
    }

    /// Translates a set of absolute grid coords so the top-left is (0,0).
    private static func normaliseToOrigin(_ coords: [CellCoord]) -> [CellCoord] {
        guard !coords.isEmpty else { return [] }
        let minR = coords.map(\.row).min()!
        let minC = coords.map(\.col).min()!
        return coords
            .map { CellCoord($0.row - minR, $0.col - minC) }
            .sorted { $0.row == $1.row ? $0.col < $1.col : $0.row < $1.row }
    }

    // MARK: - Seed

    private static func seedFromDate(_ date: Date) -> UInt64 {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        // Offset by a large prime to ensure this seed space never collides with Signals seeds
        // (which use level &* 73856093; daily seeds here start at ~20260101000000 range)
        let base = UInt64(c.year ?? 2026) * 10_000 + UInt64(c.month ?? 1) * 100 + UInt64(c.day ?? 1)
        return base &* 2_654_435_761 &+ 1_013_904_223   // Knuth multiplicative hash
    }
}

// MARK: - CargoPiece convenience init (private to generator)

private extension CargoPiece {
    init(pieceId: Int, baseCells: [CellCoord], solutionCells: [CellCoord]? = nil) {
        self.id = pieceId
        self.baseCells = baseCells
        self.rotationSteps = 0
        self.isFlipped = false
        self.solutionCells = solutionCells
    }
}
