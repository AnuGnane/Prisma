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
        
        // Basic validations
        #expect(puzzle.id < 0, "Daily puzzle should have negative ID")
        #expect(puzzle.initialGrid.letters.count == 5, "Grid should have 5 rows")
        #expect(puzzle.initialGrid.letters.allSatisfy { $0.count == 5 }, "Each row should have 5 columns")
        #expect(puzzle.targetWords.count >= 3, "Should have at least 3 target words")
        #expect(puzzle.targetWords.count <= 4, "Should have at most 4 target words")
        
        print("✅ Generated puzzle with ID: \(puzzle.id)")
        print("✅ Target words: \(puzzle.targetWords.map { $0.word })")
        print("✅ Optimal moves: \(puzzle.optimalMoveCount)")
    }
}
