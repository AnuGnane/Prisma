//
//  SignalsGameViewModel.swift
//  Prisma
//
//  Drives all Signals game logic:
//    - Daily mode: deterministic code from date seed
//    - Progression mode: code from level config
//    - Mastermind-style feedback with correct duplicate-digit handling
//    - High/Low hint comparing full numeric values
//    - Wordle-style emoji share string generation
//

import Foundation
import Observation

@Observable
final class SignalsGameViewModel: ShareStringGenerator {

    // MARK: - Game State

    private(set) var secretCode: SignalsCode
    private(set) var guessHistory: [(guess: SignalsGuess, feedback: SignalsFeedback)] = []
    private(set) var gameState: GameState = .notStarted
    private(set) var maxGuesses: Int
    private(set) var isDaily: Bool
    private(set) var activeLevelId: Int?
    private(set) var startDate: Date = .now

    /// The 4-slot input buffer. nil means the slot is empty.
    var currentInput: [Int?] = [nil, nil, nil, nil]

    var remainingGuesses: Int { maxGuesses - guessHistory.count }
    var guessCount: Int { guessHistory.count }
    var isInputComplete: Bool { currentInput.allSatisfy { $0 != nil } }

    // MARK: - Init: Daily

    init(date: Date = .now) {
        let seed = date.dailySeed
        self.secretCode  = SignalsCode(fromSeed: seed)
        self.maxGuesses  = 5
        self.isDaily     = true
        self.activeLevelId = nil
        self.gameState   = .inProgress
    }

    // MARK: - Init: Progression
    // The random code for progression generates deterministically using the level integer so it's always the same puzzle.

    init(level: Int) {
        let code = SignalsCode(fromSeed: level * 1000)
        self.secretCode = code
        self.maxGuesses = 5
        self.gameState = .inProgress
        self.isDaily = false
        self.activeLevelId = level
    }

    /// Loads a specific level, resetting all game state.
    func loadLevel(_ level: Int) {
        let code = SignalsCode(fromSeed: level * 1000)
        self.secretCode = code
        self.maxGuesses = 5
        self.gameState = .inProgress
        self.guessHistory = []
        self.currentInput = [nil, nil, nil, nil]
        self.activeLevelId = level
        self.startDate = .now
        self.isDaily = false
    }

    // MARK: - Init: Progression

    init(level: SignalsLevel) {
        // Generate a fresh random code for progression (not date-seeded)
        var rng = SystemRandomNumberGenerator()
        let digits = (0..<level.codeLength).map { _ in
            Int.random(in: level.digitRange, using: &rng)
        }
        self.secretCode  = SignalsCode(digits: digits)
        self.maxGuesses  = level.maxGuesses
        self.isDaily     = false
        self.gameState   = .inProgress
    }

    /// State of a digit key on the number pad, derived from guess history.
    enum KeyState {
        case unknown     // never guessed
        case present     // appeared as .correct or .misplaced at least once
        case absent      // every occurrence across all guesses was .absent
    }

    /// Map of digit (0–9) → its current keyboard state.
    /// Updated automatically after every submitted guess.
    var digitKeyStates: [Int: KeyState] {
        var states: [Int: KeyState] = [:]
        for (guess, feedback) in guessHistory {
            for (idx, digit) in guess.digits.enumerated() {
                let result = feedback.digitResults[idx]
                switch result {
                case .correct, .misplaced:
                    // Once a digit is confirmed present, stay present
                    states[digit] = .present
                case .absent:
                    // Only mark absent if not already known present
                    if states[digit] != .present {
                        states[digit] = .absent
                    }
                }
            }
        }
        return states
    }

    // MARK: - Input Handling

    /// Appends a digit to the next empty input slot.
    func inputDigit(_ digit: Int) {
        guard !gameState.isOver else { return }
        guard let slot = currentInput.firstIndex(of: nil) else { return }
        currentInput[slot] = digit
    }

    /// Removes the last filled digit from input.
    func deleteLastDigit() {
        guard !gameState.isOver else { return }
        // Find the last filled slot from right to left
        if let slot = currentInput.indices.last(where: { currentInput[$0] != nil }) {
            currentInput[slot] = nil
        }
    }

    // MARK: - Submit Guess

    /// Submits the current 4-digit input as a guess and computes feedback.
    func submitGuess() {
        guard !gameState.isOver else { return }
        guard isInputComplete else { return }
        let digits = currentInput.compactMap { $0 }
        guard digits.count == 4 else { return }

        let guess = SignalsGuess(digits: digits)
        let feedback = computeFeedback(guess: guess, secret: secretCode)

        guessHistory.append((guess: guess, feedback: feedback))
        currentInput = [nil, nil, nil, nil]

        // Determine new state
        if feedback.isWin {
            let score = calculateScore()
            gameState = .completed(score: score)
        } else if guessHistory.count >= maxGuesses {
            gameState = .failed
        }
        // else stays .inProgress
    }

    // MARK: - Mastermind Feedback Algorithm

    /// Computes per-digit results (green/yellow/grey) + numeric High/Low hint.
    /// Correctly handles duplicate digits in both guess and secret.
    func computeFeedback(guess: SignalsGuess, secret: SignalsCode) -> SignalsFeedback {
        var results = Array(repeating: DigitResult.absent, count: 4)
        var secretUsed = Array(repeating: false, count: 4)
        var guessUsed  = Array(repeating: false, count: 4)

        // First pass: mark correct (green) positions
        for i in 0..<4 {
            if guess.digits[i] == secret.digits[i] {
                results[i]    = .correct
                secretUsed[i] = true
                guessUsed[i]  = true
            }
        }

        // Second pass: mark misplaced (yellow) — only against unused secret digits
        for i in 0..<4 {
            guard !guessUsed[i] else { continue }
            for j in 0..<4 {
                guard !secretUsed[j], guess.digits[i] == secret.digits[j] else { continue }
                results[i]    = .misplaced
                secretUsed[j] = true
                guessUsed[i]  = true
                break
            }
        }

        // High/Low: compare full numeric values
        let valueHint: ValueHint
        let gVal = guess.numericValue
        let sVal = secret.numericValue
        if gVal > sVal {
            valueHint = .high     // guess number is too high
        } else if gVal < sVal {
            valueHint = .low      // guess number is too low
        } else {
            valueHint = .exact
        }

        return SignalsFeedback(digitResults: results, valueHint: valueHint)
    }

    // MARK: - Scoring

    /// Score out of 1000 based on number of guesses used.
    /// Fewer guesses = higher score.
    private func calculateScore() -> Int {
        let guessesUsed = guessHistory.count
        let bonus = max(0, maxGuesses - guessesUsed)  // 0..5
        // Base: 500 for solving, +100 per unused guess
        return 500 + bonus * 100
    }

    // MARK: - ShareStringGenerator

    func generateShareString() -> String {
        let dateStr = Date.now.formatted(.dateTime.day().month().year())
        var lines = ["Signals · \(dateStr)"]

        for (_, (guess, feedback)) in guessHistory.enumerated() {
            let digitEmojis = feedback.digitResults.map { result -> String in
                switch result {
                case .correct:   return "🟩"
                case .misplaced: return "🟨"
                case .absent:    return "⬜"
                }
            }.joined()

            let hintEmoji: String
            switch feedback.valueHint {
            case .high:  hintEmoji = " ⬇️"
            case .low:   hintEmoji = " ⬆️"
            case .exact: hintEmoji = " ✅"
            }

            lines.append(digitEmojis + hintEmoji)
        }

        let resultLine: String
        switch gameState {
        case .completed:
            resultLine = "\(guessHistory.count)/\(maxGuesses) ✨"
        case .failed:
            resultLine = "X/\(maxGuesses) 💀"
        default:
            resultLine = ""
        }
        if !resultLine.isEmpty { lines.append(resultLine) }

        return lines.joined(separator: "\n")
    }

    // MARK: - Testing Support

    /// Overrides the secret code and max guesses — for unit tests only.
    func overrideForTesting(secret: SignalsCode, maxGuesses: Int) {
        self.secretCode = secret
        self.maxGuesses = maxGuesses
        self.guessHistory = []
        self.currentInput = [nil, nil, nil, nil]
        self.gameState = .inProgress
    }

    // MARK: - Build a GameResult for Persistence

    func buildGameResult() -> GameResult {
        let score: Int
        switch gameState {
        case .completed(let s): score = s
        default: score = 0
        }
        return GameResult(
            gameType: .signals,
            score: score,
            shareString: generateShareString(),
            guessCount: guessHistory.count,
            isDaily: isDaily,
            durationSeconds: Date.now.timeIntervalSince(startDate)
        )
    }
}
