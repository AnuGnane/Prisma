//
//  ShiftPuzzle.swift
//  Prisma
//
//  Puzzle model for Shift v3 — 8×8, words found anywhere on board.
//

import Foundation

/// Position and direction (used for serialization / history replay).
struct WordPosition: Equatable {
    let row: Int
    let startCol: Int
    let direction: WordDirection
}

/// A target word the player must form on the board.
/// No fixed position — the word counts wherever it appears.
struct TargetWord: Equatable, Identifiable {
    let id: UUID
    let word: String

    /// Optional fixed position (for backward compat / serialization).
    /// In v3 gameplay this is IGNORED — we scan the full board.
    let position: WordPosition

    init(word: String) {
        self.id = UUID()
        self.word = word.uppercased()
        self.position = WordPosition(row: 0, startCol: 0, direction: .horizontal)
    }

    init(word: String, position: WordPosition) {
        self.id = UUID()
        self.word = word.uppercased()
        self.position = position
    }

    init(id: UUID, word: String, position: WordPosition) {
        self.id = id
        self.word = word.uppercased()
        self.position = position
    }
}

/// A complete Shift v3 puzzle.
struct ShiftPuzzle: Equatable {
    let id: Int
    let initialGrid: ShiftGrid
    let solutionGrid: ShiftGrid?
    let targetWords: [TargetWord]
    let optimalMoveCount: Int

    var isDaily: Bool { id < 0 }

    init(id: Int, initialGrid: ShiftGrid, targetWords: [TargetWord],
         optimalMoveCount: Int, solutionGrid: ShiftGrid? = nil) {
        self.id = id
        self.initialGrid = initialGrid
        self.solutionGrid = solutionGrid
        self.targetWords = targetWords
        self.optimalMoveCount = optimalMoveCount
    }
}
