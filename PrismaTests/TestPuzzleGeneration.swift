//
//  TestPuzzleGeneration.swift
//  PrismaTests
//
//  Quick test to verify puzzle generation works
//

import Testing
@testable import Prisma
import Foundation

struct TestPuzzleGeneration {
    
    @Test("Generate daily puzzle successfully")
    func testBasicPuzzleGeneration() throws {
        // Test that we can generate a puzzle without crashing
        let date = Date()
        let puzzle = ShiftPuzzleGenerator.generateDailyPuzzle(for: date)
        
        // Basic validations — Shift v3: 8×8 grid, 5–7 target words
        #expect(puzzle.id < 0, "Daily puzzle should have negative ID")
        #expect(puzzle.initialGrid.letters.count == 8, "Grid should have 8 rows")
        #expect(puzzle.initialGrid.letters.allSatisfy { $0.count == 8 }, "Each row should have 8 columns")
        #expect(puzzle.targetWords.count >= 5, "Should have at least 5 target words")
        #expect(puzzle.targetWords.count <= 7, "Should have at most 7 target words")

        print("✅ Generated puzzle with ID: \(puzzle.id)")
        print("✅ Target words: \(puzzle.targetWords.map { $0.word })")
    }
}
