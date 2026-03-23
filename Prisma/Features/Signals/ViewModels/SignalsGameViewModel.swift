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

@Observable @MainActor
final class SignalsGameViewModel: ShareStringGenerator {

    // MARK: - Game State

    private(set) var secretCode: SignalsCode
    private(set) var guessHistory: [(guess: SignalsGuess, feedback: SignalsFeedback)] = []
    private(set) var gameState: GameState = .notStarted
    private(set) var maxGuesses: Int
    private(set) var isDaily: Bool
    private(set) var activeLevelId: Int?
    private(set) var startDate: Date = .now
    
    // MARK: - Analysis
    
    var showPossibleCodes: Bool = false
    private(set) var possibleCodesCount: Int = 10000

    // MARK: - Timer

    private(set) var elapsedSeconds: Double = 0
    private var timerTask: Task<Void, Never>?
    private var timerStarted = false

    var timerString: String {
        let minutes = Int(elapsedSeconds) / 60
        let seconds = Int(elapsedSeconds) % 60
        return "\(minutes):\(seconds.formatted(.number.precision(.integerLength(2))))"
    }

    private func startTimer() {
        let start = Date()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .nanoseconds(250_000_000))
                guard let self = self else { break }
                await MainActor.run { self.elapsedSeconds = Date().timeIntervalSince(start) }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

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
        let seed = level &* 73856093 ^ 19349669
        let code = SignalsCode(fromSeed: seed)
        self.secretCode = code
        self.maxGuesses = 5
        self.gameState = .inProgress
        self.isDaily = false
        self.activeLevelId = level
    }

    /// Loads a specific level, resetting all game state.
    func loadLevel(_ level: Int) {
        let seed = level &* 73856093 ^ 19349669
        let code = SignalsCode(fromSeed: seed)
        self.secretCode = code
        self.maxGuesses = 5
        self.gameState = .inProgress
        self.guessHistory = []
        self.currentInput = [nil, nil, nil, nil]
        self.activeLevelId = level
        self.startDate = .now
        self.isDaily = false
        self.elapsedSeconds = 0
        self.timerStarted = false
        stopTimer()
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

    /// Toggles the possible codes counter and updates the count.
    func togglePossibleCodesCounter() {
        showPossibleCodes.toggle()
        if showPossibleCodes {
            updatePossibleCodesCount()
        }
    }

    /// Pre-generated list of all 10,000 possible 4-digit codes.
    private static let allPossibleCodes: [SignalsCode] = {
        var codes: [SignalsCode] = []
        for d1 in 0...9 {
            for d2 in 0...9 {
                for d3 in 0...9 {
                    for d4 in 0...9 {
                        codes.append(SignalsCode(digits: [d1, d2, d3, d4]))
                    }
                }
            }
        }
        return codes
    }()

    /// Calculates how many of the 10,000 possible codes are still valid given the history.
    private func updatePossibleCodesCount() {
        guard !guessHistory.isEmpty else {
            possibleCodesCount = 10000
            return
        }

        // We can run this on a background thread if it's too slow, but 10k iterations of 
        // local math is usually < 5ms on modern iPhones.
        let currentHistory = guessHistory
        let count = Self.allPossibleCodes.filter { candidate in
            for historyEntry in currentHistory {
                let feedback = Self.computeFeedback(guess: historyEntry.guess, secret: candidate)
                if feedback != historyEntry.feedback {
                    return false
                }
            }
            return true
        }.count
        
        self.possibleCodesCount = count
    }

    // MARK: - Input Handling

    /// Appends a digit to the next empty input slot.
    func inputDigit(_ digit: Int) {
        guard !gameState.isOver else { return }
        guard let slot = currentInput.firstIndex(of: nil) else {
            Haptics.playError()
            SoundManager.playError()
            return 
        }
        currentInput[slot] = digit
        Haptics.playLightImpact()
        SoundManager.playTap()
    }

    /// Removes the last filled digit from input.
    func deleteLastDigit() {
        guard !gameState.isOver else { return }
        // Find the last filled slot from right to left
        if let slot = currentInput.indices.last(where: { currentInput[$0] != nil }) {
            currentInput[slot] = nil
            Haptics.playLightImpact()
            SoundManager.playTap()
        }
    }

    // MARK: - Submit Guess

    /// Submits the current 4-digit input as a guess and computes feedback.
    func submitGuess() {
        guard !gameState.isOver else { return }
        guard isInputComplete else {
            Haptics.playError()
            SoundManager.playError()
            return 
        }
        let digits = currentInput.compactMap { $0 }
        guard digits.count == 4 else { return }

        if !timerStarted { startTimer(); timerStarted = true }

        let guess = SignalsGuess(digits: digits)
        let feedback = Self.computeFeedback(guess: guess, secret: secretCode)

        guessHistory.append((guess: guess, feedback: feedback))
        currentInput = [nil, nil, nil, nil]
        
        if showPossibleCodes {
            updatePossibleCodesCount()
        }

        // Determine new state
        if feedback.isWin {
            let score = calculateScore()
            gameState = .completed(score: score)
            stopTimer()
            Haptics.playSuccess()
            SoundManager.playSuccess()
        } else if guessHistory.count >= maxGuesses {
            gameState = .failed
            stopTimer()
            Haptics.playError()
            SoundManager.playError()
        } else {
            Haptics.playMediumImpact()
            SoundManager.playClick()
        }
    }

    // MARK: - Mastermind Feedback Algorithm

    /// Computes per-digit results (green/yellow/grey) + numeric High/Low hint.
    /// Correctly handles duplicate digits in both guess and secret.
    static func computeFeedback(guess: SignalsGuess, secret: SignalsCode) -> SignalsFeedback {
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

        for (_, (_, feedback)) in guessHistory.enumerated() {
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
        
        // Serialize the complete guess history
        let guessHistoryWithFeedback = guessHistory.map { (guess, feedback) in
            SignalsGuessWithFeedback(guess: guess, feedback: feedback)
        }
        let serializedState = SignalsStateSerializer.serialize(guessHistoryWithFeedback)
        if serializedState == nil {
            print("⚠️ SignalsGameViewModel: Failed to serialize guess history")
        }
        
        return GameResult(
            gameType: .signals,
            score: score,
            shareString: generateShareString(),
            guessCount: guessHistory.count,
            isDaily: isDaily,
            durationSeconds: elapsedSeconds,
            levelId: activeLevelId,
            signalsStateJSON: serializedState
        )
    }
    func reset() {
        if isDaily {
            self.secretCode = SignalsCode(fromSeed: Int(Date().dailySeed))
        } else if let levelId = activeLevelId {
            let seed = levelId &* 73856093 ^ 19349669
            self.secretCode = SignalsCode(fromSeed: seed)
        }
        
        self.guessHistory = []
        self.currentInput = [nil, nil, nil, nil]
        self.gameState = .inProgress
        self.startDate = Date.now
        self.showingSolution = false
        self.elapsedSeconds = 0
        self.timerStarted = false
        stopTimer()
    }

    // MARK: - Give Up

    private(set) var showingSolution = false

    func giveUp() {
        guard gameState == .inProgress else { return }
        gameState = .gaveUp
        stopTimer()
    }

    func showSolution() { showingSolution = true }
    func hideSolution() { showingSolution = false }

    /// The secret code digits for display
    var solutionDigits: [Int] { secretCode.digits }
}
