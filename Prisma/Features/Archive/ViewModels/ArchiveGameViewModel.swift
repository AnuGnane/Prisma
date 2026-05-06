//
//  ArchiveGameViewModel.swift
//  Prisma
//
//  Drives Archive game logic:
//    - Daily mode: deterministic event from date seed
//    - Mastermind-style per-digit feedback (8 digits, DD/MM/YYYY)
//    - Arrow hint comparing full YYYYMMDD values
//    - Date validation (rejects invalid dates with no penalty)
//    - Wordle-style emoji share string
//

import Foundation
import Observation

@Observable @MainActor
final class ArchiveGameViewModel: ShareStringGenerator {

    // MARK: - Game State

    private(set) var secretEvent: ArchiveEvent
    private(set) var guessHistory: [(guess: ArchiveGuess, feedback: ArchiveFeedback)] = []
    private(set) var gameState: GameState = .notStarted
    private(set) var maxGuesses: Int
    private(set) var startDate: Date = .now

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
                try? await Task.sleep(for: .milliseconds(250))
                guard let self = self else { break }
                await MainActor.run { self.elapsedSeconds = Date().timeIntervalSince(start) }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private(set) var isDaily: Bool
    private(set) var activeLevelId: Int?

    /// 8-slot input buffer. nil = empty.
    var currentInput: [Int?] = Array(repeating: nil, count: 8)

    /// True when the last submission was an invalid date — drives a shake animation.
    var showInvalidShake = false

    /// Brief message shown when the user enters an invalid date.
    var invalidDateMessage: String? = nil

    var remainingGuesses: Int { maxGuesses - guessHistory.count }
    var guessCount: Int { guessHistory.count }
    var isInputComplete: Bool { currentInput.allSatisfy { $0 != nil } }

    // MARK: - Event Loading

    private static var cachedEvents: [ArchiveEvent]?

    private static func loadEvents() -> [ArchiveEvent] {
        if let cached = cachedEvents { return cached }
        guard let url = Bundle.main.url(forResource: "archive_events", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([ArchiveEvent].self, from: data),
              !events.isEmpty else {
            // Fallback event if JSON fails to load
            let fallback = ArchiveEvent(id: 0, day: 1, month: 1, year: 2000,
                                        hint: "A new millennium begins", event: "Y2K",
                                        funFact: "The Y2K bug cost the world over $300 billion to prepare for.")
            return [fallback]
        }
        cachedEvents = events
        return events
    }

    // MARK: - Daily Event Loading (separate 365-event pool)

    private static var cachedDailyEvents: [ArchiveEvent]?

    private static func loadDailyEvents() -> [ArchiveEvent] {
        if let cached = cachedDailyEvents { return cached }
        guard let url = Bundle.main.url(forResource: "archive_events_daily", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([ArchiveEvent].self, from: data),
              !events.isEmpty else {
            // Fall back to local events if daily pool not found
            return loadEvents()
        }
        cachedDailyEvents = events
        return events
    }

    /// Returns the daily event for a given date (for viewing past solutions).
    static func dailyEvent(for date: Date) -> ArchiveEvent {
        let events = loadDailyEvents()
        let dayOfYear = (Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1) - 1
        let index = dayOfYear % events.count
        return events[index]
    }

    /// Returns the event for a local level (for viewing past solutions).
    static func event(forLevel levelId: Int) -> ArchiveEvent {
        let events = loadEvents()
        let index = max(0, levelId - 1) % events.count
        return events[index]
    }

    // MARK: - Init: Daily

    init(date: Date = .now) {
        self.secretEvent = Self.dailyEvent(for: date)
        self.maxGuesses = 7
        self.gameState = .inProgress
        self.isDaily = true
        self.activeLevelId = nil
    }

    // MARK: - Init: Progression Level

    init(level: Int) {
        let events = Self.loadEvents()
        // Level 1 gets index 0, Level 30 gets index 29. Wrap around if > 30.
        let index = max(0, level - 1) % events.count
        self.secretEvent = events[index]
        self.maxGuesses = 7
        self.gameState = .inProgress
        self.isDaily = false
        self.activeLevelId = level
    }

    /// Loads a specific level, resetting all game state.
    func loadLevel(_ level: Int) {
        let events = Self.loadEvents()
        let index = max(0, level - 1) % events.count
        self.secretEvent = events[index]
        self.maxGuesses = 7
        self.gameState = .inProgress
        self.guessHistory = []
        self.currentInput = Array(repeating: nil, count: 8)
        self.isDaily = false
        self.activeLevelId = level
        self.startDate = .now
        self.elapsedSeconds = 0
        self.timerStarted = false
        stopTimer()
    }

    // MARK: - Input Handling

    func inputDigit(_ digit: Int) {
        guard !gameState.isOver else { return }
        guard let slot = currentInput.firstIndex(of: nil) else {
            Haptics.playError()
            return
        }
        currentInput[slot] = digit
        Haptics.playLightImpact()
        SoundManager.playTap()
    }

    func deleteLastDigit() {
        guard !gameState.isOver else { return }
        if let slot = currentInput.indices.last(where: { currentInput[$0] != nil }) {
            currentInput[slot] = nil
            Haptics.playLightImpact()
            SoundManager.playTap()
        }
    }

    // MARK: - Digit Key States (for keypad dimming)

    enum KeyState {
        case unknown, present, absent
    }

    var digitKeyStates: [Int: KeyState] {
        var states: [Int: KeyState] = [:]
        for (guess, feedback) in guessHistory {
            for (idx, digit) in guess.digits.enumerated() {
                let result = feedback.digitResults[idx]
                switch result {
                case .correct, .misplaced:
                    states[digit] = .present
                case .absent:
                    if states[digit] != .present {
                        states[digit] = .absent
                    }
                }
            }
        }
        return states
    }

    // MARK: - Submit Guess

    func submitGuess() {
        guard !gameState.isOver else { return }
        guard isInputComplete else {
            Haptics.playError()
            return 
        }
        let digits = currentInput.compactMap { $0 }
        guard digits.count == 8 else { return }

        let guess = ArchiveGuess(digits: digits)

        // Validate date
        guard guess.isValidDate else {
            showInvalidShake = true
            invalidDateMessage = "Invalid date"
            Task {
                try? await Task.sleep(for: .seconds(2))
                showInvalidShake = false
                invalidDateMessage = nil
            }
            Haptics.playError()
            return
        }

        if !timerStarted { startTimer(); timerStarted = true }

        let feedback = computeFeedback(guess: guess)
        guessHistory.append((guess: guess, feedback: feedback))
        currentInput = Array(repeating: nil, count: 8)

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
        } else {
            Haptics.playMediumImpact()
            SoundManager.playClick()
        }
    }

    // MARK: - Mastermind Feedback (8-digit)

    func computeFeedback(guess: ArchiveGuess) -> ArchiveFeedback {
        let secret = secretEvent.dateDigits
        let guessDigits = guess.digits

        var results = Array(repeating: DigitResult.absent, count: 8)
        var secretUsed = Array(repeating: false, count: 8)
        var guessUsed  = Array(repeating: false, count: 8)

        // Pass 1: exact matches (green)
        for i in 0..<8 {
            if guessDigits[i] == secret[i] {
                results[i]    = .correct
                secretUsed[i] = true
                guessUsed[i]  = true
            }
        }

        // Pass 2: misplaced (yellow) — across all 8 positions
        for i in 0..<8 {
            guard !guessUsed[i] else { continue }
            for j in 0..<8 {
                guard !secretUsed[j], guessDigits[i] == secret[j] else { continue }
                results[i]    = .misplaced
                secretUsed[j] = true
                guessUsed[i]  = true
                break
            }
        }

        // Arrow: compare YYYYMMDD values
        let valueHint: ValueHint
        let gVal = guess.numericValue
        let sVal = secretEvent.numericValue
        if gVal > sVal {
            valueHint = .high    // guess is newer → go older
        } else if gVal < sVal {
            valueHint = .low     // guess is older → go newer
        } else {
            valueHint = .exact
        }

        return ArchiveFeedback(digitResults: results, valueHint: valueHint)
    }

    // MARK: - Score

    private func calculateScore() -> Int {
        let bonus = max(0, maxGuesses - guessHistory.count)
        return 500 + bonus * 100
    }

    // MARK: - Share String

    func generateShareString() -> String {
        let dateStr = Date.now.formatted(.dateTime.day().month().year())
        var lines = ["Archive · \(dateStr)"]

        for (_, (_, feedback)) in guessHistory.enumerated() {
            let emojis = feedback.digitResults.map { r -> String in
                switch r {
                case .correct:   return "🟩"
                case .misplaced: return "🟨"
                case .absent:    return "⬜"
                }
            }
            // Group as DD / MM / YYYY: 2 + 2 + 4
            let grouped = emojis[0..<2].joined() + " " +
                          emojis[2..<4].joined() + " " +
                          emojis[4..<8].joined()

            let hint: String
            switch feedback.valueHint {
            case .high:  hint = " ⬇️"
            case .low:   hint = " ⬆️"
            case .exact: hint = " ✅"
            }
            lines.append(grouped + hint)
        }

        let result: String
        switch gameState {
        case .completed: result = "\(guessHistory.count)/\(maxGuesses) ✨"
        case .failed:    result = "X/\(maxGuesses) 💀"
        default:         result = ""
        }
        if !result.isEmpty { lines.append(result) }

        return lines.joined(separator: "\n")
    }

    // MARK: - Testing Support

    func overrideForTesting(event: ArchiveEvent, maxGuesses: Int) {
        self.secretEvent = event
        self.maxGuesses = maxGuesses
        self.guessHistory = []
        self.currentInput = Array(repeating: nil, count: 8)
        self.gameState = .inProgress
    }

    // MARK: - Build GameResult

    func buildGameResult() -> GameResult {
        let score: Int
        switch gameState {
        case .completed(let s): score = s
        default: score = 0
        }
        
        // Serialize guess history for persistence
        let guessesWithFeedback = guessHistory.map { (guess, feedback) in
            ArchiveGuessWithFeedback(guess: guess, feedback: feedback)
        }
        let serializedState = ArchiveStateSerializer.serialize(guessesWithFeedback)
        
        if serializedState == nil {
            print("⚠️ ArchiveGameViewModel: Failed to serialize guess history")
        }
        
        return GameResult(
            gameType: .archive,
            score: score,
            shareString: generateShareString(),
            guessCount: guessHistory.count,
            isDaily: isDaily,
            durationSeconds: elapsedSeconds,
            levelId: activeLevelId,
            archiveStateJSON: serializedState
        )
    }
    func reset() {
        if isDaily {
            let events = Self.loadDailyEvents()
            let dayOfYear = (Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1) - 1
            let index = dayOfYear % events.count
            self.secretEvent = events[index]
        } else if let levelId = activeLevelId {
            let events = Self.loadEvents()
            let index = max(0, levelId - 1) % events.count
            self.secretEvent = events[index]
        }
        
        self.guessHistory = []
        self.currentInput = Array(repeating: nil, count: 8)
        self.gameState = .inProgress
        self.startDate = .now
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

    /// The secret event for display
    var solutionEvent: ArchiveEvent { secretEvent }
}
