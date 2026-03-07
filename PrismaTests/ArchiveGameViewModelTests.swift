//
//  ArchiveGameViewModelTests.swift
//  PrismaTests
//
//  Tests for ArchiveGameViewModel game state serialization.
//

import Foundation
import Testing
@testable import Prisma

struct ArchiveGameViewModelTests {
    
    // MARK: - Game State Serialization
    
    @Test("buildGameResult includes serialized guess history for daily mode")
    func testBuildGameResultSerializesGuessHistoryDaily() {
        // Create a daily mode game
        let vm = ArchiveGameViewModel(date: .now)
        
        // Override with a known event for testing
        let testEvent = ArchiveEvent(
            id: 1,
            day: 15,
            month: 8,
            year: 1947,
            hint: "Independence Day",
            event: "India gains independence"
        )
        vm.overrideForTesting(event: testEvent, maxGuesses: 7)
        
        // Make a guess
        vm.currentInput = [1, 0, 0, 8, 1, 9, 4, 7]
        vm.submitGuess()
        
        let result = vm.buildGameResult()
        
        // Verify the result has serialized state
        #expect(result.archiveStateJSON != nil, "Archive state should be serialized")
        #expect(result.isDaily == true, "Should be marked as daily mode")
        #expect(result.guessCount == 1, "Should have 1 guess")
        
        // Verify deserialization works
        if let json = result.archiveStateJSON {
            let deserialized = ArchiveStateSerializer.deserialize(json)
            #expect(deserialized != nil, "Should be able to deserialize")
            #expect(deserialized?.count == 1, "Should have 1 guess in deserialized state")
        }
    }
    
    @Test("buildGameResult includes serialized guess history for local mode")
    func testBuildGameResultSerializesGuessHistoryLocal() {
        // Create a local mode game
        let vm = ArchiveGameViewModel(level: 5)
        
        // Make a guess
        vm.currentInput = [0, 1, 0, 1, 2, 0, 0, 0]
        vm.submitGuess()
        
        let result = vm.buildGameResult()
        
        // Verify the result has serialized state
        #expect(result.archiveStateJSON != nil, "Archive state should be serialized")
        #expect(result.isDaily == false, "Should be marked as local mode")
        #expect(result.guessCount == 1, "Should have 1 guess")
        
        // Verify deserialization works
        if let json = result.archiveStateJSON {
            let deserialized = ArchiveStateSerializer.deserialize(json)
            #expect(deserialized != nil, "Should be able to deserialize")
            #expect(deserialized?.count == 1, "Should have 1 guess in deserialized state")
        }
    }
    
    @Test("buildGameResult handles empty guess history")
    func testBuildGameResultWithNoGuesses() {
        // Create a game without making any guesses
        let vm = ArchiveGameViewModel(date: .now)
        
        let result = vm.buildGameResult()
        
        // Should still have serialized state (empty array)
        #expect(result.archiveStateJSON != nil, "Should serialize empty guess history")
        
        // Verify deserialization works for empty array
        if let json = result.archiveStateJSON {
            let deserialized = ArchiveStateSerializer.deserialize(json)
            #expect(deserialized != nil, "Should be able to deserialize empty array")
            #expect(deserialized?.isEmpty == true, "Deserialized array should be empty")
        }
    }
    
    @Test("buildGameResult handles serialization failure gracefully")
    func testBuildGameResultHandlesSerializationFailure() {
        // This test verifies that even if serialization fails,
        // the GameResult is still created with other properties intact
        let vm = ArchiveGameViewModel(date: .now)
        
        // Make a guess
        vm.currentInput = [1, 5, 0, 8, 1, 9, 4, 7]
        vm.submitGuess()
        
        let result = vm.buildGameResult()
        
        // Even if serialization fails, other properties should be set
        #expect(result.gameType == .archive, "Game type should be archive")
        #expect(result.guessCount == 1, "Guess count should be correct")
        #expect(result.isDaily == true, "Daily flag should be set")
        #expect(result.durationSeconds >= 0, "Duration should be non-negative")
    }
}
