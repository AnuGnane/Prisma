//
//  ShiftGameViewModel.swift
//  Prisma
//
//  ViewModel for Shift v3 — 8×8, words found anywhere, no hints/par.
//

import Foundation
import Observation
import UIKit

@Observable @MainActor
final class ShiftGameViewModel {

    // MARK: - Game Data

    private(set) var puzzle: ShiftPuzzle
    var currentGrid: ShiftGrid
    private(set) var gameState: ShiftGameState = .inProgress

    // MARK: - Solution View

    private(set) var showingSolution = false

    // MARK: - Move Tracking

    private(set) var moveHistory: [ShiftMove] = []
    private(set) var undoStack: [ShiftMove] = []
    private(set) var redoStack: [ShiftMove] = []

    var moveCount: Int { moveHistory.count }
    var canUndo: Bool { !undoStack.isEmpty && gameState == .inProgress }
    var canRedo: Bool { !redoStack.isEmpty && gameState == .inProgress }

    // MARK: - Word Completion

    private(set) var completedWords: Set<UUID> = []
    private(set) var foundLocations: [UUID: FoundWordLocation] = [:]

    var allWordsCompleted: Bool {
        guard !puzzle.targetWords.isEmpty else { return false }
        return completedWords.count == puzzle.targetWords.count
    }

    // MARK: - Timer

    private(set) var elapsedSeconds: Double = 0
    private var timerTask: Task<Void, Never>?
    private var timerStarted = false

    // MARK: - Mode

    let isDaily: Bool
    let activeLevelId: Int?

    // MARK: - Init

    init(puzzle: ShiftPuzzle, isDaily: Bool, levelId: Int? = nil) {
        self.puzzle = puzzle
        self.currentGrid = puzzle.initialGrid
        self.isDaily = isDaily
        self.activeLevelId = levelId
        scanForWords()
    }

    /// Restore from a previously saved grid (mid-game exit)
    init(puzzle: ShiftPuzzle, restoredGrid: ShiftGrid, isDaily: Bool, levelId: Int? = nil) {
        self.puzzle = puzzle
        self.currentGrid = restoredGrid
        self.isDaily = isDaily
        self.activeLevelId = levelId
        scanForWords()
    }

    // MARK: - Move Operations

    func performMove(_ move: ShiftMove) {
        guard gameState == .inProgress else { return }
        if !timerStarted { startTimer(); timerStarted = true }

        currentGrid = move.apply(to: currentGrid)
        moveHistory.append(move)
        undoStack.append(move)
        redoStack.removeAll()

        Haptics.playLightImpact()
        SoundManager.playTap()

        scanForWords()
        checkWinCondition()
    }

    func undo() {
        guard canUndo, let last = undoStack.popLast() else { return }
        currentGrid = last.inverse.apply(to: currentGrid)
        redoStack.append(last)
        if !moveHistory.isEmpty { moveHistory.removeLast() }
        
        Haptics.playLightImpact()
        SoundManager.playTap()
        
        scanForWords()
    }

    func redo() {
        guard canRedo, let move = redoStack.popLast() else { return }
        currentGrid = move.apply(to: currentGrid)
        moveHistory.append(move)
        undoStack.append(move)
        
        Haptics.playLightImpact()
        SoundManager.playTap()
        
        scanForWords()
        checkWinCondition()
    }

    func reset() {
        currentGrid = puzzle.initialGrid
        moveHistory.removeAll()
        undoStack.removeAll()
        redoStack.removeAll()
        completedWords.removeAll()
        foundLocations.removeAll()
        elapsedSeconds = 0
        timerStarted = false
        timerTask?.cancel()
        showingSolution = false
        gameState = .inProgress
        scanForWords()
    }

    // MARK: - Give Up

    func giveUp() {
        guard gameState == .inProgress else { return }
        timerTask?.cancel()
        gameState = .gaveUp
    }

    func showSolution() { showingSolution = true }
    func hideSolution() { showingSolution = false }

    var solutionGrid: ShiftGrid? { puzzle.solutionGrid }

    // MARK: - Word Scanning

    func scanForWords() {
        let prevCount = completedWords.count
        completedWords.removeAll()
        foundLocations.removeAll()

        for target in puzzle.targetWords {
            if let loc = currentGrid.findWord(target.word) {
                completedWords.insert(target.id)
                foundLocations[target.id] = loc
            }
        }

        if completedWords.count > prevCount {
            Haptics.playMediumImpact()
            SoundManager.playSuccess()
            UIAccessibility.post(notification: .announcement, argument: "Word found!")
        }
    }

    private func checkWinCondition() {
        if allWordsCompleted {
            timerTask?.cancel()
            let score = calculateScore()
            gameState = .completed(score: score)
            
            Haptics.playSuccess()
            SoundManager.playSuccess()
            
            UIAccessibility.post(notification: .announcement, argument: "Puzzle completed!")
        }
    }

    // MARK: - Highlighted Cells

    var highlightedCells: Set<Int> {
        var cells = Set<Int>()
        for (_, loc) in foundLocations {
            for cell in loc.cells { cells.insert(cell.row * ShiftGrid.size + cell.col) }
        }
        return cells
    }

    // MARK: - Score (1000 max, points per word)

    /// Partial score based on words found so far
    var currentScore: Int {
        guard !puzzle.targetWords.isEmpty else { return 0 }
        let wordPoints = 1000 / puzzle.targetWords.count
        let wordsFound = completedWords.count
        let base = wordsFound * wordPoints
        let movePenalty = min(base / 2, moveCount * 3)
        return max(0, base - movePenalty)
    }

    private func calculateScore() -> Int {
        // Full completion: 1000 minus penalties
        let movePenalty = min(300, moveCount * 5)
        let timePenalty = min(200, Int(elapsedSeconds / 3))
        return max(100, 1000 - movePenalty - timePenalty)
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask = Task { [weak self] in
            let start = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self = self else { break }
                await MainActor.run { self.elapsedSeconds = Date().timeIntervalSince(start) }
            }
        }
    }

    var timerString: String {
        let minutes = Int(elapsedSeconds) / 60
        let seconds = Int(elapsedSeconds) % 60
        return "\(minutes):\(seconds.formatted(.number.precision(.integerLength(2))))"
    }

    // MARK: - Share

    func generateShareString() -> String {
        let label = isDaily ? Date.now.formatted(date: .abbreviated, time: .omitted) : "Level \(activeLevelId ?? 0)"
        return """
        Prisma Shift · \(label)
        \(moveCount) moves · \(timerString)
        """
    }

    // MARK: - Game Result

    func buildGameResult() -> GameResult {
        let score: Int
        if case .completed(let s) = gameState { score = s } else { score = 0 }

        let serialized = ShiftStateSerializer.serialize(
            grid: currentGrid, targetWords: puzzle.targetWords, moveHistory: moveHistory
        )

        return GameResult(
            gameType: .shift, date: .now, score: score,
            shareString: generateShareString(), guessCount: moveCount,
            isDaily: isDaily, durationSeconds: elapsedSeconds,
            levelId: activeLevelId, shiftStateJSON: serialized
        )
    }
}

enum ShiftGameState: Equatable {
    case inProgress
    case completed(score: Int)
    case gaveUp
}
