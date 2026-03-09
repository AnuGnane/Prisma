//
//  ShiftLevelData.swift
//  Prisma
//
//  JSON-decodable level data for Shift v3 (8×8, free-position words).
//  Builds a proper solution grid programmatically.
//

import Foundation

struct ShiftLevelData: Codable {
    let levelId: Int
    let initialGrid: [[String]]        // 8×8
    let targetWords: [TargetWordData]
    let optimalMoves: Int

    func toPuzzle() -> ShiftPuzzle? {
        let size = ShiftGrid.size

        guard initialGrid.count == size,
              initialGrid.allSatisfy({ $0.count == size }),
              initialGrid.allSatisfy({ row in row.allSatisfy { $0.count == 1 } }) else {
            print("❌ ShiftLevelData: Invalid grid for level \(levelId)")
            return nil
        }

        let letters = initialGrid.map { $0.compactMap { $0.uppercased().first } }
        let baseGrid = ShiftGrid(letters: letters)
        let words = targetWords.map { $0.word.uppercased() }
        let targetWordObjs = words.map { TargetWord(word: $0) }

        // Build a proper solution grid with all words placed
        var rng = SeededRandomNumberGenerator(seed: UInt64(levelId) * 31337)
        let solutionGrid = ShiftLevelData.buildSolutionGrid(
            words: words, baseGrid: baseGrid, using: &rng
        )

        // Scramble from the solution grid until NO words are found
        var scrambled = solutionGrid
        var scrambleAttempts = 0
        while scrambleAttempts < 30 {
            let anyFound = targetWordObjs.contains { scrambled.findWord($0.word) != nil }
            if !anyFound { break }

            for _ in 0..<max(4, optimalMoves) {
                let t = Int.random(in: 0..<4, using: &rng)
                let i = Int.random(in: 0..<size, using: &rng)
                let move: ShiftMove
                switch t {
                case 0: move = .rowLeft(i)
                case 1: move = .rowRight(i)
                case 2: move = .columnUp(i)
                default: move = .columnDown(i)
                }
                scrambled = move.apply(to: scrambled)
            }
            scrambleAttempts += 1
        }

        return ShiftPuzzle(
            id: levelId, initialGrid: scrambled,
            targetWords: targetWordObjs, optimalMoveCount: optimalMoves,
            solutionGrid: solutionGrid
        )
    }

    /// Builds a grid with all target words placed in valid positions.
    /// Uses the base grid as filler for non-word cells.
    private static func buildSolutionGrid(
        words: [String],
        baseGrid: ShiftGrid,
        using rng: inout SeededRandomNumberGenerator
    ) -> ShiftGrid {
        let size = ShiftGrid.size
        var grid = Array(repeating: Array(repeating: Character("?"), count: size), count: size)
        let dirs: [WordDirection] = WordDirection.allCases

        for word in words {
            let chars = Array(word)
            var placed = false
            var attempts = 0

            while !placed && attempts < 100 {
                attempts += 1
                let dir = dirs.randomElement(using: &rng)!
                let (dR, dC) = dir.delta

                let maxR = dir == .diagonalUp
                    ? size - 1
                    : size - 1 - max(0, (chars.count - 1) * dR)
                let minR = dir == .diagonalUp ? max(0, chars.count - 1) : 0
                let maxC = size - 1 - max(0, (chars.count - 1) * dC)

                guard minR <= maxR, maxC >= 0 else { continue }

                let startR = Int.random(in: minR...maxR, using: &rng)
                let startC = Int.random(in: 0...maxC, using: &rng)

                // Check that cells are empty or already match
                var canPlace = true
                var r = startR, c = startC
                for ch in chars {
                    if grid[r][c] != "?" && grid[r][c] != ch {
                        canPlace = false; break
                    }
                    r += dR; c += dC
                }

                if canPlace {
                    r = startR; c = startC
                    for ch in chars {
                        grid[r][c] = ch
                        r += dR; c += dC
                    }
                    placed = true
                }
            }
        }

        // Fill remaining cells from the base grid or random letters
        let filler: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for r in 0..<size {
            for c in 0..<size {
                if grid[r][c] == "?" {
                    // Use the base grid letter if available, else random
                    grid[r][c] = baseGrid[r, c] != " " ? baseGrid[r, c] :
                        filler.randomElement(using: &rng)!
                }
            }
        }

        return ShiftGrid(letters: grid)
    }
}

struct TargetWordData: Codable {
    let word: String
    let direction: String?

    init(word: String, direction: String? = nil) {
        self.word = word
        self.direction = direction
    }
}
