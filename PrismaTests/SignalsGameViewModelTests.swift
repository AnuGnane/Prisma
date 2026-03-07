//
//  SignalsGameViewModelTests.swift
//  PrismaTests
//

import Testing
import Foundation
@testable import Prisma

@Suite("SignalsGameViewModel")
struct SignalsGameViewModelTests {

    // MARK: - Helpers

    func makeVM(secret: [Int]) -> SignalsGameViewModel {
        let vm = SignalsGameViewModel(date: .now)
        // Override the secret via testable init
        return SignalsGameViewModelTestHelper.make(secret: secret, maxGuesses: 6)
    }

    // MARK: - Feedback Algorithm

    @Test("All correct digits → all .correct results")
    func testAllCorrect() {
        let vm = makeVM(secret: [1, 2, 3, 4])
        let guess = SignalsGuess(digits: [1, 2, 3, 4])
        let fb = vm.computeFeedback(guess: guess, secret: SignalsCode(digits: [1, 2, 3, 4]))
        #expect(fb.digitResults == [.correct, .correct, .correct, .correct])
        #expect(fb.valueHint == .exact)
        #expect(fb.isWin == true)
    }

    @Test("Completely wrong digits → all .absent")
    func testAllAbsent() {
        let fb = SignalsGameViewModel(date: .now).computeFeedback(
            guess:  SignalsGuess(digits: [5, 6, 7, 8]),
            secret: SignalsCode(digits:  [1, 2, 3, 4])
        )
        #expect(fb.digitResults == [.absent, .absent, .absent, .absent])
    }

    @Test("Mixed correct + misplaced + absent")
    func testPartialMatch() {
        // Secret: [1,2,3,4], Guess: [1,4,5,2]
        // pos0: 1==1 → correct
        // pos1: 4!=2, but 4 is in secret at pos3 → misplaced
        // pos2: 5 not in secret → absent
        // pos3: 2!=4, but 2 is in secret at pos1 (still unused) → misplaced
        let fb = SignalsGameViewModel(date: .now).computeFeedback(
            guess:  SignalsGuess(digits: [1, 4, 5, 2]),
            secret: SignalsCode(digits:  [1, 2, 3, 4])
        )
        #expect(fb.digitResults[0] == .correct)
        #expect(fb.digitResults[1] == .misplaced)
        #expect(fb.digitResults[2] == .absent)
        #expect(fb.digitResults[3] == .misplaced)
    }

    @Test("Duplicate digit in guess vs single in secret: only one yellow")
    func testDuplicateGuessDigit() {
        // Secret: [1,2,3,4], Guess: [1,1,1,1]
        // pos0: correct; pos1,2,3: only one '1' in secret and it's already matched → absent
        let fb = SignalsGameViewModel(date: .now).computeFeedback(
            guess:  SignalsGuess(digits: [1, 1, 1, 1]),
            secret: SignalsCode(digits:  [1, 2, 3, 4])
        )
        #expect(fb.digitResults[0] == .correct)
        #expect(fb.digitResults[1] == .absent)
        #expect(fb.digitResults[2] == .absent)
        #expect(fb.digitResults[3] == .absent)
    }

    @Test("Duplicate digit in secret: correctly allocates yellows")
    func testDuplicateSecretDigit() {
        // Secret: [1,1,2,3], Guess: [1,2,1,3]
        // pos0: 1==1 → correct
        // pos1: 2!=1, 2 is at secret[2] → misplaced
        // pos2: 1!=2, 1 is at secret[1] (unused) → misplaced
        // pos3: 3==3 → correct
        let fb = SignalsGameViewModel(date: .now).computeFeedback(
            guess:  SignalsGuess(digits: [1, 2, 1, 3]),
            secret: SignalsCode(digits:  [1, 1, 2, 3])
        )
        #expect(fb.digitResults == [.correct, .misplaced, .misplaced, .correct])
    }

    // MARK: - High / Low Arrow

    @Test("Guess number higher than secret → .high hint")
    func testHighArrow() {
        // Guess 5441 > Secret 3215
        let fb = SignalsGameViewModel(date: .now).computeFeedback(
            guess:  SignalsGuess(digits: [5, 4, 4, 1]),
            secret: SignalsCode(digits:  [3, 2, 1, 5])
        )
        #expect(fb.valueHint == .high)
    }

    @Test("Guess number lower than secret → .low hint")
    func testLowArrow() {
        // Guess 1234 < Secret 5678
        let fb = SignalsGameViewModel(date: .now).computeFeedback(
            guess:  SignalsGuess(digits: [1, 2, 3, 4]),
            secret: SignalsCode(digits:  [5, 6, 7, 8])
        )
        #expect(fb.valueHint == .low)
    }

    @Test("Guess equals secret → .exact hint")
    func testExactArrow() {
        let fb = SignalsGameViewModel(date: .now).computeFeedback(
            guess:  SignalsGuess(digits: [1, 2, 3, 4]),
            secret: SignalsCode(digits:  [1, 2, 3, 4])
        )
        #expect(fb.valueHint == .exact)
    }

    // MARK: - Game State

    @Test("Correct guess transitions state to .completed")
    func testCorrectGuessWins() {
        let vm = SignalsGameViewModelTestHelper.make(secret: [3, 7, 0, 5], maxGuesses: 6)
        vm.currentInput = [3, 7, 0, 5]
        vm.submitGuess()
        if case .completed = vm.gameState { } else {
            Issue.record("Expected .completed but got \(vm.gameState)")
        }
    }

    @Test("Exhausting max guesses transitions to .failed")
    func testMaxGuessesReachedFails() {
        let vm = SignalsGameViewModelTestHelper.make(secret: [1, 2, 3, 4], maxGuesses: 6)
        // Submit 6 wrong guesses
        for _ in 0..<6 {
            vm.currentInput = [9, 9, 9, 9]
            vm.submitGuess()
        }
        #expect(vm.gameState == .failed)
    }

    // MARK: - Daily Seed

    @Test("Same date produces same secret code")
    func testDeterministicSeed() {
        let date = Date(timeIntervalSinceReferenceDate: 825_638_400) // fixed reference date
        let vm1 = SignalsGameViewModel(date: date)
        let vm2 = SignalsGameViewModel(date: date)
        #expect(vm1.secretCode == vm2.secretCode)
    }

    @Test("Different dates produce different seeds")
    func testDifferentDatesProduceDifferentSeeds() {
        let d1 = Date(timeIntervalSinceReferenceDate: 825_638_400)
        let d2 = d1.addingTimeInterval(86400) // +1 day
        #expect(d1.dailySeed != d2.dailySeed)
    }

    // MARK: - Share String

    @Test("Share string contains game name and emoji rows")
    func testShareStringGeneration() {
        let vm = SignalsGameViewModelTestHelper.make(secret: [1, 2, 3, 4], maxGuesses: 6)
        vm.currentInput = [9, 9, 9, 9]
        vm.submitGuess()
        vm.currentInput = [1, 2, 3, 4]
        vm.submitGuess()
        let share = vm.generateShareString()
        #expect(share.contains("Signals"))
        #expect(share.contains("🟩"))
        #expect(share.contains("✅") || share.contains("2/6"))
    }
    
    // MARK: - Game State Serialization
    
    @Test("buildGameResult includes serialized guess history for daily mode")
    func testBuildGameResultSerializesGuessHistoryDaily() {
        let vm = SignalsGameViewModel(date: .now)
        vm.overrideForTesting(secret: SignalsCode(digits: [1, 2, 3, 4]), maxGuesses: 6)
        
        // Submit a few guesses
        vm.currentInput = [5, 6, 7, 8]
        vm.submitGuess()
        vm.currentInput = [1, 2, 3, 4]
        vm.submitGuess()
        
        let result = vm.buildGameResult()
        
        // Verify the result has serialized state
        #expect(result.signalsStateJSON != nil)
        #expect(result.isDaily == true)
        #expect(result.guessCount == 2)
        
        // Verify we can deserialize it back
        if let json = result.signalsStateJSON {
            let deserialized = SignalsStateSerializer.deserialize(json)
            #expect(deserialized != nil)
            #expect(deserialized?.count == 2)
        }
    }
    
    @Test("buildGameResult includes serialized guess history for local mode")
    func testBuildGameResultSerializesGuessHistoryLocal() {
        let vm = SignalsGameViewModel(level: 5)
        
        // Submit a few guesses
        vm.currentInput = [9, 9, 9, 9]
        vm.submitGuess()
        vm.currentInput = [8, 8, 8, 8]
        vm.submitGuess()
        
        let result = vm.buildGameResult()
        
        // Verify the result has serialized state
        #expect(result.signalsStateJSON != nil)
        #expect(result.isDaily == false)
        #expect(result.guessCount == 2)
        
        // Verify we can deserialize it back
        if let json = result.signalsStateJSON {
            let deserialized = SignalsStateSerializer.deserialize(json)
            #expect(deserialized != nil)
            #expect(deserialized?.count == 2)
        }
    }
    
    @Test("buildGameResult handles empty guess history")
    func testBuildGameResultWithNoGuesses() {
        let vm = SignalsGameViewModel(date: .now)
        
        let result = vm.buildGameResult()
        
        // Should still have serialized state (empty array)
        #expect(result.signalsStateJSON != nil)
        #expect(result.guessCount == 0)
        
        // Verify we can deserialize it back
        if let json = result.signalsStateJSON {
            let deserialized = SignalsStateSerializer.deserialize(json)
            #expect(deserialized != nil)
            #expect(deserialized?.count == 0)
        }
    }
}

// MARK: - Test Helper

/// Provides a way to create a ViewModel with a known secret code in tests.
enum SignalsGameViewModelTestHelper {
    static func make(secret: [Int], maxGuesses: Int) -> SignalsGameViewModel {
        let vm = SignalsGameViewModel(date: .now)
        vm.overrideForTesting(secret: SignalsCode(digits: secret), maxGuesses: maxGuesses)
        return vm
    }
}
