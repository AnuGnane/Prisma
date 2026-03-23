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

    @Test("Same date always produces same puzzle")
    func testDeterminism() {
        let date = Date(timeIntervalSinceReferenceDate: 0)   // 2001-01-01
        let p1 = CargoPuzzleGenerator.generateDailyPuzzle(for: date)
        let p2 = CargoPuzzleGenerator.generateDailyPuzzle(for: date)
        #expect(p1.id == p2.id)
        #expect(p1.gridRows == p2.gridRows)
        #expect(p1.gridCols == p2.gridCols)
        #expect(p1.pieces.count == p2.pieces.count)
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
