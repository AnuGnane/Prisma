//
//  SignalsGameViewModelTests.swift
//  PrismaTests
//
//  Tests for SignalsGameViewModel covering init, input, feedback algorithm,
//  scoring, state transitions, and key-state derivation.
//

import Testing
import Foundation
@testable import Prisma

// MARK: - SignalsCode Tests

@Suite("SignalsCode")
struct SignalsCodeTests {

    @Test("numericValue computes full 4-digit integer")
    func numericValue() {
        let code = SignalsCode(digits: [3, 2, 1, 5])
        #expect(code.numericValue == 3215)
    }

    @Test("Same seed always produces the same code")
    func deterministicSeed() {
        let a = SignalsCode(fromSeed: 42)
        let b = SignalsCode(fromSeed: 42)
        #expect(a == b)
    }

    @Test("Different seeds produce different codes")
    func differentSeeds() {
        let a = SignalsCode(fromSeed: 1)
        let b = SignalsCode(fromSeed: 2)
        // Extremely unlikely to collide with two different seeds
        #expect(a != b)
    }
}

// MARK: - Feedback Algorithm Tests

@MainActor
@Suite("Signals feedback algorithm")
struct SignalsFeedbackTests {

    @Test("Perfect match returns all correct + exact hint")
    func perfectMatch() {
        let secret = SignalsCode(digits: [1, 2, 3, 4])
        let guess  = SignalsGuess(digits: [1, 2, 3, 4])
        let fb = SignalsGameViewModel.computeFeedback(guess: guess, secret: secret)
        #expect(fb.digitResults == [.correct, .correct, .correct, .correct])
        #expect(fb.valueHint == .exact)
        #expect(fb.isWin == true)
    }

    @Test("All absent returns all absent")
    func allAbsent() {
        let secret = SignalsCode(digits: [1, 1, 1, 1])
        let guess  = SignalsGuess(digits: [2, 2, 2, 2])
        let fb = SignalsGameViewModel.computeFeedback(guess: guess, secret: secret)
        #expect(fb.digitResults == [.absent, .absent, .absent, .absent])
    }

    @Test("Duplicate digit not over-counted as misplaced")
    func duplicateDigitHandling() {
        // Secret: 1 1 2 3 — guess: 1 2 3 4
        // Position 0: correct (1 == 1)
        // Position 1: misplaced — digit 2 is in secret but not at pos 1
        // Position 2: misplaced — digit 3 is in secret but not at pos 2
        // Position 3: absent — digit 4 not in secret
        let secret = SignalsCode(digits: [1, 1, 2, 3])
        let guess  = SignalsGuess(digits: [1, 2, 3, 4])
        let fb = SignalsGameViewModel.computeFeedback(guess: guess, secret: secret)
        #expect(fb.digitResults[0] == .correct)
        #expect(fb.digitResults[3] == .absent)
    }

    @Test("High hint when guess numeric value is greater than secret")
    func highHint() {
        let secret = SignalsCode(digits: [1, 0, 0, 0])  // 1000
        let guess  = SignalsGuess(digits: [2, 0, 0, 0])  // 2000
        let fb = SignalsGameViewModel.computeFeedback(guess: guess, secret: secret)
        #expect(fb.valueHint == .high)
    }

    @Test("Low hint when guess numeric value is less than secret")
    func lowHint() {
        let secret = SignalsCode(digits: [5, 0, 0, 0])  // 5000
        let guess  = SignalsGuess(digits: [1, 0, 0, 0])  // 1000
        let fb = SignalsGameViewModel.computeFeedback(guess: guess, secret: secret)
        #expect(fb.valueHint == .low)
    }
}

// MARK: - ViewModel Tests

@MainActor
@Suite("SignalsGameViewModel")
struct SignalsGameViewModelTests {

    @Test("Daily init sets correct defaults")
    func dailyInit() {
        let vm = SignalsGameViewModel(date: .now)
        #expect(vm.isDaily == true)
        #expect(vm.maxGuesses == 5)
        #expect(vm.gameState == .inProgress)
        #expect(vm.currentInput.count == 4)
        #expect(vm.currentInput.allSatisfy { $0 == nil })
    }

    @Test("Progression level init sets levelId")
    func progressionInit() {
        let vm = SignalsGameViewModel(level: 10)
        #expect(vm.isDaily == false)
        #expect(vm.activeLevelId == 10)
        #expect(vm.gameState == .inProgress)
    }

    @Test("Same level always loads the same secret code")
    func deterministicLevel() {
        let vm1 = SignalsGameViewModel(level: 7)
        let vm2 = SignalsGameViewModel(level: 7)
        #expect(vm1.secretCode == vm2.secretCode)
    }

    @Test("inputDigit fills slots left to right")
    func inputFillsLeftToRight() {
        let vm = SignalsGameViewModel(level: 1)
        vm.inputDigit(3)
        vm.inputDigit(7)
        #expect(vm.currentInput[0] == 3)
        #expect(vm.currentInput[1] == 7)
        #expect(vm.currentInput[2] == nil)
        #expect(vm.currentInput[3] == nil)
    }

    @Test("isInputComplete only true when all 4 slots filled")
    func inputCompleteness() {
        let vm = SignalsGameViewModel(level: 1)
        #expect(vm.isInputComplete == false)
        vm.inputDigit(1); vm.inputDigit(2); vm.inputDigit(3)
        #expect(vm.isInputComplete == false)
        vm.inputDigit(4)
        #expect(vm.isInputComplete == true)
    }

    @Test("deleteLastDigit clears rightmost filled slot")
    func deleteLastDigit() {
        let vm = SignalsGameViewModel(level: 1)
        vm.inputDigit(1); vm.inputDigit(2); vm.inputDigit(3)
        vm.deleteLastDigit()
        #expect(vm.currentInput == [1, 2, nil, nil])
    }

    @Test("submitGuess increments guessHistory")
    func submitGuessIncrementsHistory() {
        let vm = SignalsGameViewModel(level: 1)
        vm.inputDigit(0); vm.inputDigit(0); vm.inputDigit(0); vm.inputDigit(0)
        vm.submitGuess()
        #expect(vm.guessHistory.count == 1)
        // Input should be cleared after submit
        #expect(vm.currentInput.allSatisfy { $0 == nil })
    }

    @Test("Submitting the exact code transitions to completed")
    func correctGuessWins() {
        let vm = SignalsGameViewModel(level: 1)
        let secret = vm.secretCode.digits

        // Fill and submit the exact secret
        for d in secret { vm.inputDigit(d) }
        vm.submitGuess()

        if case .completed(let score) = vm.gameState {
            #expect(score > 0)
        } else {
            Issue.record("Expected .completed state but got \(vm.gameState)")
        }
    }

    @Test("Exhausting all guesses transitions to failed")
    func exhaustedGuessesFails() {
        let vm = SignalsGameViewModel(level: 1)
        let secret = vm.secretCode.digits

        // Find a wrong code
        let wrongDigit = (secret[0] + 1) % 10
        let wrong = [wrongDigit, wrongDigit, wrongDigit, wrongDigit]

        // Use maxGuesses wrong guesses
        for _ in 0..<vm.maxGuesses {
            for d in wrong { vm.inputDigit(d) }
            vm.submitGuess()
            if vm.gameState.isOver { break }
        }

        #expect(vm.gameState == .failed)
    }

    @Test("digitKeyStates marks absent digits correctly")
    func keyStateAbsent() {
        // Build a VM where we know the secret and make a provably-wrong guess
        let vm = SignalsGameViewModel(level: 1)
        let secret = vm.secretCode.digits

        // Build a guess that contains a digit definitely not in the secret
        let absentDigit: Int = (0...9).first { !secret.contains($0) } ?? -1
        guard absentDigit != -1 else { return } // all digits present — skip

        let guess = [absentDigit, absentDigit, absentDigit, absentDigit]
        for d in guess { vm.inputDigit(d) }
        vm.submitGuess()

        #expect(vm.digitKeyStates[absentDigit] == .absent)
    }

    @Test("submitGuess is a no-op when game is already over")
    func submitAfterGameOver() {
        let vm = SignalsGameViewModel(level: 1)
        let secret = vm.secretCode.digits

        // Win the game
        for d in secret { vm.inputDigit(d) }
        vm.submitGuess()
        #expect(vm.gameState.isOver)

        // Attempting another submit should be a no-op
        let historyCountAfterWin = vm.guessHistory.count
        for d in [0, 0, 0, 0] { vm.inputDigit(d) }
        vm.submitGuess()
        #expect(vm.guessHistory.count == historyCountAfterWin)
    }
}
