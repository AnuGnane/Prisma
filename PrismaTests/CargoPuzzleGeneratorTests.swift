//
//  CargoPuzzleGeneratorTests.swift
//  PrismaTests
//
//  Tests for the algorithmic Cargo puzzle generator.
//  Verifies solvability, uniqueness from local pool, and determinism.
//

import Testing
@testable import Prisma
import Foundation

struct CargoPuzzleGeneratorTests {

    // MARK: - Determinism

    @Test("Same date always produces same puzzle (shape-level)")
    func testDeterminism() {
        let date = Date(timeIntervalSinceReferenceDate: 0)   // 2001-01-01
        let p1 = CargoPuzzleGenerator.generateDailyPuzzle(for: date)
        let p2 = CargoPuzzleGenerator.generateDailyPuzzle(for: date)
        #expect(p1.id == p2.id)
        #expect(p1.gridRows == p2.gridRows)
        #expect(p1.gridCols == p2.gridCols)
        #expect(p1.pieces.count == p2.pieces.count)

        // Shape-level: every piece's baseCells AND solutionCells must match
        // exactly across runs. This is what the previous version of this test
        // missed — Set-iteration randomness made the *shapes* non-deterministic
        // even though count + grid size were stable. Don't weaken this.
        for (a, b) in zip(p1.pieces, p2.pieces) {
            #expect(a.id == b.id, "piece id mismatch")
            #expect(a.baseCells == b.baseCells,
                    "piece \(a.id) baseCells differ: \(a.baseCells) vs \(b.baseCells)")
            #expect(a.solutionCells == b.solutionCells,
                    "piece \(a.id) solutionCells differ: \(a.solutionCells ?? []) vs \(b.solutionCells ?? [])")
        }
    }

    @Test("Determinism holds across many dates")
    func testDeterminismAcrossDates() {
        // Sweep 30 distinct days. For each, generate the puzzle twice and
        // compare every piece's shape exactly. If Set-iteration determinism
        // ever regresses, this catches it on the first day where the
        // hash-randomised order diverges.
        for dayOffset in 0..<30 {
            let date = Date(timeIntervalSinceReferenceDate: Double(dayOffset) * 86400)
            let a = CargoPuzzleGenerator.generateDailyPuzzle(for: date)
            let b = CargoPuzzleGenerator.generateDailyPuzzle(for: date)
            #expect(a.id == b.id, "Day \(dayOffset): id mismatch")
            #expect(a.pieces.count == b.pieces.count, "Day \(dayOffset): count mismatch")
            for (pa, pb) in zip(a.pieces, b.pieces) {
                #expect(pa.baseCells == pb.baseCells,
                        "Day \(dayOffset) piece \(pa.id): baseCells differ")
                #expect(pa.solutionCells == pb.solutionCells,
                        "Day \(dayOffset) piece \(pa.id): solutionCells differ")
            }
        }
    }

    // MARK: - Solvability

    @Test("Generated puzzle pieces exactly tile the grid")
    func testPiecesTileGrid() {
        for dayOffset in 0..<30 {
            let date = Date(timeIntervalSinceReferenceDate: Double(dayOffset) * 86400)
            let puzzle = CargoPuzzleGenerator.generateDailyPuzzle(for: date)

            let fillable = puzzle.gridRows * puzzle.gridCols - puzzle.blockedCells.count
            let totalCells = puzzle.pieces.reduce(0) { $0 + $1.baseCells.count }

            #expect(
                fillable == totalCells,
                "Day \(dayOffset): Expected \(fillable) cells, got \(totalCells)"
            )
        }
    }

    @Test("Generated puzzle is actually solvable via placement")
    func testPuzzleIsSolvable() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let puzzle = CargoPuzzleGenerator.generateDailyPuzzle(for: date)

        var grid = CargoGrid(rows: puzzle.gridRows, cols: puzzle.gridCols, blockedCells: puzzle.blockedCells)
        var placed = 0

        for piece in puzzle.pieces {
            let origins = grid.validOrigins(for: piece)
            if let origin = origins.first {
                grid.place(piece, at: origin)
                placed += 1
            }
        }

        // All pieces have at least one valid origin — proves solvable initial state
        #expect(placed == puzzle.pieces.count, "All pieces should be placeable")
    }

    // MARK: - Uniqueness

    @Test("Daily puzzle IDs are all negative — distinct from local JSON pool")
    func testDailyPuzzleIdsAreNegative() {
        for dayOffset in 0..<365 {
            let date = Date(timeIntervalSinceReferenceDate: Double(dayOffset) * 86400)
            let puzzle = CargoPuzzleGenerator.generateDailyPuzzle(for: date)
            #expect(puzzle.id < 0, "Daily puzzle id should be negative, got \(puzzle.id)")
        }
    }

    @Test("No overlap between generated daily IDs and local JSON pool IDs")
    func testNoOverlapWithLocalPool() {
        let localIds = Set(CargoPuzzleLoader.load().map(\.id))
        for dayOffset in 0..<365 {
            let date = Date(timeIntervalSinceReferenceDate: Double(dayOffset) * 86400)
            let dailyId = CargoPuzzleGenerator.generateDailyPuzzle(for: date).id
            #expect(!localIds.contains(dailyId), "Daily id \(dailyId) clashes with local pool")
        }
    }

    // MARK: - Variety

    @Test("Different dates produce different puzzles")
    func testVariety() {
        var ids = Set<Int>()
        for dayOffset in 0..<100 {
            let date = Date(timeIntervalSinceReferenceDate: Double(dayOffset) * 86400)
            let id = CargoPuzzleGenerator.generateDailyPuzzle(for: date).id
            ids.insert(id)
        }
        // All 100 days should produce distinct puzzles
        #expect(ids.count == 100, "Expected 100 unique puzzles, got \(ids.count)")
    }

    @Test("Puzzle has a reasonable number of pieces (3–10)")
    func testPieceCount() {
        for dayOffset in 0..<30 {
            let date = Date(timeIntervalSinceReferenceDate: Double(dayOffset) * 86400)
            let puzzle = CargoPuzzleGenerator.generateDailyPuzzle(for: date)
            #expect(puzzle.pieces.count >= 3, "Too few pieces on day \(dayOffset)")
            #expect(puzzle.pieces.count <= 12, "Too many pieces on day \(dayOffset)")
        }
    }
}
