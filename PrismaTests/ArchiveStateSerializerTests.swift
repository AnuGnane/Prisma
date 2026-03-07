//
//  ArchiveStateSerializerTests.swift
//  PrismaTests
//

import Testing
import Foundation
@testable import Prisma

@Suite("ArchiveStateSerializer")
struct ArchiveStateSerializerTests {
    
    // MARK: - Round-Trip Tests
    
    @Test("Empty guess history serializes and deserializes correctly")
    func testEmptyHistory() {
        let guesses: [ArchiveGuessWithFeedback] = []
        
        guard let json = ArchiveStateSerializer.serialize(guesses) else {
            Issue.record("Serialization failed for empty history")
            return
        }
        
        guard let deserialized = ArchiveStateSerializer.deserialize(json) else {
            Issue.record("Deserialization failed for empty history")
            return
        }
        
        #expect(deserialized.isEmpty)
    }
    
    @Test("Single guess with all correct digits serializes correctly")
    func testSingleCorrectGuess() {
        let guess = ArchiveGuess(digits: [2, 0, 0, 7, 1, 9, 6, 9])
        let feedback = ArchiveFeedback(
            digitResults: [.correct, .correct, .correct, .correct, .correct, .correct, .correct, .correct],
            valueHint: .exact
        )
        let guesses = [ArchiveGuessWithFeedback(guess: guess, feedback: feedback)]
        
        guard let json = ArchiveStateSerializer.serialize(guesses) else {
            Issue.record("Serialization failed")
            return
        }
        
        guard let deserialized = ArchiveStateSerializer.deserialize(json) else {
            Issue.record("Deserialization failed")
            return
        }
        
        #expect(deserialized.count == 1)
        #expect(deserialized[0].guess.digits == guess.digits)
        #expect(deserialized[0].feedback.digitResults == feedback.digitResults)
        #expect(deserialized[0].feedback.valueHint == feedback.valueHint)
    }
    
    @Test("Multiple guesses with mixed feedback serialize correctly")
    func testMultipleGuesses() {
        let guesses = [
            ArchiveGuessWithFeedback(
                guess: ArchiveGuess(digits: [1, 5, 0, 4, 1, 9, 1, 2]),
                feedback: ArchiveFeedback(
                    digitResults: [.absent, .absent, .misplaced, .absent, .correct, .correct, .absent, .absent],
                    valueHint: .low
                )
            ),
            ArchiveGuessWithFeedback(
                guess: ArchiveGuess(digits: [2, 0, 0, 7, 1, 9, 6, 9]),
                feedback: ArchiveFeedback(
                    digitResults: [.correct, .correct, .misplaced, .absent, .correct, .correct, .correct, .correct],
                    valueHint: .high
                )
            ),
            ArchiveGuessWithFeedback(
                guess: ArchiveGuess(digits: [2, 0, 0, 6, 1, 9, 6, 9]),
                feedback: ArchiveFeedback(
                    digitResults: [.correct, .correct, .correct, .correct, .correct, .correct, .correct, .correct],
                    valueHint: .exact
                )
            )
        ]
        
        guard let json = ArchiveStateSerializer.serialize(guesses) else {
            Issue.record("Serialization failed")
            return
        }
        
        guard let deserialized = ArchiveStateSerializer.deserialize(json) else {
            Issue.record("Deserialization failed")
            return
        }
        
        #expect(deserialized.count == 3)
        
        // Verify first guess
        #expect(deserialized[0].guess.digits == guesses[0].guess.digits)
        #expect(deserialized[0].feedback.digitResults == guesses[0].feedback.digitResults)
        #expect(deserialized[0].feedback.valueHint == guesses[0].feedback.valueHint)
        
        // Verify second guess
        #expect(deserialized[1].guess.digits == guesses[1].guess.digits)
        #expect(deserialized[1].feedback.digitResults == guesses[1].feedback.digitResults)
        #expect(deserialized[1].feedback.valueHint == guesses[1].feedback.valueHint)
        
        // Verify third guess
        #expect(deserialized[2].guess.digits == guesses[2].guess.digits)
        #expect(deserialized[2].feedback.digitResults == guesses[2].feedback.digitResults)
        #expect(deserialized[2].feedback.valueHint == guesses[2].feedback.valueHint)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Invalid JSON returns nil")
    func testInvalidJSON() {
        let invalidJSON = "{ invalid json }"
        let result = ArchiveStateSerializer.deserialize(invalidJSON)
        #expect(result == nil)
    }
    
    @Test("Empty string returns nil")
    func testEmptyString() {
        let result = ArchiveStateSerializer.deserialize("")
        #expect(result == nil)
    }
    
    @Test("Malformed JSON structure returns nil")
    func testMalformedStructure() {
        let malformedJSON = "{\"guesses\": \"not an array\"}"
        let result = ArchiveStateSerializer.deserialize(malformedJSON)
        #expect(result == nil)
    }
    
    @Test("Missing required fields returns nil")
    func testMissingFields() {
        let missingFieldsJSON = "{\"guesses\": [{\"digits\": [1,2,3,4,5,6,7,8]}]}"
        let result = ArchiveStateSerializer.deserialize(missingFieldsJSON)
        #expect(result == nil)
    }
    
    // MARK: - Edge Cases
    
    @Test("Maximum guesses (6) serialize correctly")
    func testMaximumGuesses() {
        let guesses = (0..<6).map { i in
            ArchiveGuessWithFeedback(
                guess: ArchiveGuess(digits: [i, i, i, i, i, i, i, i]),
                feedback: ArchiveFeedback(
                    digitResults: Array(repeating: .absent, count: 8),
                    valueHint: .low
                )
            )
        }
        
        guard let json = ArchiveStateSerializer.serialize(guesses) else {
            Issue.record("Serialization failed for 6 guesses")
            return
        }
        
        guard let deserialized = ArchiveStateSerializer.deserialize(json) else {
            Issue.record("Deserialization failed for 6 guesses")
            return
        }
        
        #expect(deserialized.count == 6)
    }
    
    @Test("All digit result types serialize correctly")
    func testAllDigitResultTypes() {
        let guess = ArchiveGuess(digits: [1, 2, 3, 4, 5, 6, 7, 8])
        let feedback = ArchiveFeedback(
            digitResults: [.correct, .correct, .misplaced, .misplaced, .absent, .absent, .correct, .misplaced],
            valueHint: .high
        )
        let guesses = [ArchiveGuessWithFeedback(guess: guess, feedback: feedback)]
        
        guard let json = ArchiveStateSerializer.serialize(guesses) else {
            Issue.record("Serialization failed")
            return
        }
        
        guard let deserialized = ArchiveStateSerializer.deserialize(json) else {
            Issue.record("Deserialization failed")
            return
        }
        
        #expect(deserialized[0].feedback.digitResults == feedback.digitResults)
    }
    
    @Test("All value hint types serialize correctly")
    func testAllValueHintTypes() {
        let guesses = [
            ArchiveGuessWithFeedback(
                guess: ArchiveGuess(digits: [1, 0, 0, 1, 2, 0, 0, 0]),
                feedback: ArchiveFeedback(
                    digitResults: Array(repeating: .absent, count: 8),
                    valueHint: .low
                )
            ),
            ArchiveGuessWithFeedback(
                guess: ArchiveGuess(digits: [3, 1, 1, 2, 2, 0, 5, 0]),
                feedback: ArchiveFeedback(
                    digitResults: Array(repeating: .absent, count: 8),
                    valueHint: .high
                )
            ),
            ArchiveGuessWithFeedback(
                guess: ArchiveGuess(digits: [2, 0, 0, 6, 1, 9, 6, 9]),
                feedback: ArchiveFeedback(
                    digitResults: Array(repeating: .correct, count: 8),
                    valueHint: .exact
                )
            )
        ]
        
        guard let json = ArchiveStateSerializer.serialize(guesses) else {
            Issue.record("Serialization failed")
            return
        }
        
        guard let deserialized = ArchiveStateSerializer.deserialize(json) else {
            Issue.record("Deserialization failed")
            return
        }
        
        #expect(deserialized[0].feedback.valueHint == .low)
        #expect(deserialized[1].feedback.valueHint == .high)
        #expect(deserialized[2].feedback.valueHint == .exact)
    }
}
