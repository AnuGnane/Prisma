//
//  ShiftGameViewModelTests.swift
//  PrismaTests
//
//  Tests for ShiftGameViewModel covering move operations, undo/redo,
//  and word-completion detection.
//

import Testing
import Foundation
@testable import Prisma

// MARK: - Helpers

/// Returns a blank 8×8 ShiftGrid filled with 'A'.
private func blankGrid() -> ShiftGrid {
    let row = Array(repeating: Character("A"), count: 8)
    return ShiftGrid(letters: Array(repeating: row, count: 8))
}

/// Returns a ShiftPuzzle with a known initial grid and no target words.
private func simplePuzzle(grid: ShiftGrid = blankGrid()) -> ShiftPuzzle {
    ShiftPuzzle(id: 0, initialGrid: grid, targetWords: [], solutionGrid: nil)
}

// MARK: - ShiftGrid Move Tests

@Suite("ShiftGrid operations")
struct ShiftGridTests {

    @Test("slideRowLeft wraps first element to end")
    func slideRowLeft() {
        var letters = Array(repeating: Array(repeating: Character("A"), count: 8), count: 8)
        // Set row 0 to A,B,C,D,E,F,G,H
        for c in 0..<8 { letters[0][c] = Character(UnicodeScalar(65 + c)!) }
        let grid = ShiftGrid(letters: letters)
        let shifted = grid.slideRowLeft(0)
        // After sliding left: B,C,D,E,F,G,H,A
        #expect(shifted.letters[0][0] == "B")
        #expect(shifted.letters[0][7] == "A")
    }

    @Test("slideRowRight wraps last element to start")
    func slideRowRight() {
        var letters = Array(repeating: Array(repeating: Character("A"), count: 8), count: 8)
        for c in 0..<8 { letters[0][c] = Character(UnicodeScalar(65 + c)!) }
        let grid = ShiftGrid(letters: letters)
        let shifted = grid.slideRowRight(0)
        // After sliding right: H,A,B,C,D,E,F,G
        #expect(shifted.letters[0][0] == "H")
        #expect(shifted.letters[0][1] == "A")
    }

    @Test("Applying inverse of a move restores original grid")
    func inverseRestoresGrid() {
        let original = blankGrid()
        var letters = original.letters
        letters[0][0] = "Z"
        let modified = ShiftGrid(letters: letters)

        let move: ShiftMove = .rowLeft(0)
        let moved = move.apply(to: modified)
        let restored = move.inverse.apply(to: moved)
        #expect(restored == modified)
    }

    @Test("rowLeft and rowRight are inverses of each other")
    func rowMoveInverses() {
        let grid = blankGrid()
        let moved = ShiftMove.rowLeft(2).apply(to: grid)
        let back  = ShiftMove.rowRight(2).apply(to: moved)
        #expect(back == grid)
    }

    @Test("columnUp and columnDown are inverses of each other")
    func columnMoveInverses() {
        let grid = blankGrid()
        let moved = ShiftMove.columnUp(3).apply(to: grid)
        let back  = ShiftMove.columnDown(3).apply(to: moved)
        #expect(back == grid)
    }
}

// MARK: - ShiftGameViewModel Tests

@MainActor
@Suite("ShiftGameViewModel")
struct ShiftGameViewModelTests {

    @Test("Initial state has no moves and is in progress")
    func initialState() {
        let vm = ShiftGameViewModel(puzzle: simplePuzzle(), isDaily: false)
        #expect(vm.moveCount == 0)
        #expect(vm.canUndo == false)
        #expect(vm.canRedo == false)
        #expect(vm.gameState == .inProgress)
    }

    @Test("performMove increments move count")
    func performMoveIncrements() {
        let vm = ShiftGameViewModel(puzzle: simplePuzzle(), isDaily: false)
        vm.performMove(.rowLeft(0))
        #expect(vm.moveCount == 1)
        #expect(vm.canUndo == true)
    }

    @Test("undo decrements move count and restores grid")
    func undoRestoresGrid() {
        let puzzle = simplePuzzle()
        let vm = ShiftGameViewModel(puzzle: puzzle, isDaily: false)
        let originalGrid = vm.currentGrid

        vm.performMove(.rowLeft(0))
        #expect(vm.currentGrid != originalGrid)

        vm.undo()
        #expect(vm.currentGrid == originalGrid)
        #expect(vm.moveCount == 0)
        #expect(vm.canRedo == true)
    }

    @Test("redo re-applies an undone move")
    func redoReappliesMove() {
        let vm = ShiftGameViewModel(puzzle: simplePuzzle(), isDaily: false)
        vm.performMove(.rowLeft(0))
        let gridAfterMove = vm.currentGrid

        vm.undo()
        vm.redo()
        #expect(vm.currentGrid == gridAfterMove)
        #expect(vm.canRedo == false)
    }

    @Test("New move clears redo stack")
    func newMoveClearsRedo() {
        let vm = ShiftGameViewModel(puzzle: simplePuzzle(), isDaily: false)
        vm.performMove(.rowLeft(0))
        vm.undo()
        #expect(vm.canRedo == true)

        vm.performMove(.rowRight(1))
        #expect(vm.canRedo == false)
    }

    @Test("allWordsCompleted is false when no words are found")
    func notCompletedWithoutWords() {
        // Puzzle with a target word that blank grid can't satisfy
        let word = TargetWord(word: "SWIFT")
        let puzzle = ShiftPuzzle(id: 0, initialGrid: blankGrid(), targetWords: [word], solutionGrid: nil)
        let vm = ShiftGameViewModel(puzzle: puzzle, isDaily: false)
        #expect(vm.allWordsCompleted == false)
    }

    @Test("Restoring a saved grid applies it at init")
    func restoredGridInit() {
        let puzzle = simplePuzzle()
        let vm = ShiftGameViewModel(puzzle: puzzle, isDaily: false)
        vm.performMove(.columnUp(0))
        let savedGrid = vm.currentGrid

        // Simulate restoring from saved state
        let restored = ShiftGameViewModel(puzzle: puzzle, restoredGrid: savedGrid, isDaily: false)
        #expect(restored.currentGrid == savedGrid)
    }
}
