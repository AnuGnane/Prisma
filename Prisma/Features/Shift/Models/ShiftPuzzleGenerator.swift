//
//  ShiftPuzzleGenerator.swift
//  Prisma
//
//  Daily puzzle generator for Shift v3 (8×8, min 5 words, lengths 3-8).
//

import Foundation

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

struct ShiftPuzzleGenerator {

    // Word bank: shorter words more common, longer words rare
    private static let words3: [String] = [
        "CAT","DOG","SUN","RUN","FLY","SKY","MAP","CUP","PEN","RED",
        "BIG","OLD","NEW","HOT","ICE","OWL","FOX","BEE","ANT","ELF",
        "OAK","AXE","GEM","ORB","RIB","JAW","KEY","NET","LOG","BOW"
    ]
    private static let words4: [String] = [
        "FISH","BIRD","TREE","STAR","MOON","LAKE","FIRE","WIND","SNOW","WOLF",
        "BEAR","FROG","LION","GOLD","BLUE","DARK","GLOW","WAVE","SEED","RAIN",
        "ROCK","LAMP","BELL","DRUM","CAVE","HILL","ROSE","VINE","HAWK","DUST"
    ]
    private static let words5: [String] = [
        "OCEAN","FLAME","STORM","PLANT","STONE","LIGHT","HEART","DREAM","SMILE","TOWER",
        "RIVER","CLOUD","PEARL","CROWN","SWORD","MAGIC","MUSIC","DANCE","EARTH","FROST",
        "EAGLE","CRANE","WHALE","SHELL","CORAL","BLOOM","GRAIN","MARSH","TRAIL","RIDGE"
    ]
    private static let words6: [String] = [
        "GARDEN","FOREST","CASTLE","BRIDGE","ISLAND","STREAM","CANDLE","SILVER","GOLDEN","BREEZE",
        "SUNSET","RABBIT","DRAGON","TURTLE","FALCON","COBALT","MEADOW","VALLEY","HARBOR","SUMMIT"
    ]
    private static let words7: [String] = [
        "DIAMOND","CRYSTAL","THUNDER","BLOSSOM","LANTERN","FEATHER","MONARCH","SPARROW","PHOENIX","GLACIER"
    ]
    private static let words8: [String] = [
        "MOUNTAIN","TREASURE","MIDNIGHT","ELEPHANT","STARFISH","CROSSING","AMETHYST","SAPPHIRE"
    ]

    // MARK: - Daily Puzzle

    static func generateDailyPuzzle(for date: Date) -> ShiftPuzzle {
        let seed = seedFromDate(date)
        var rng = SeededRandomNumberGenerator(seed: seed)

        let wordCount = Int.random(in: 5...7, using: &rng)
        let selected = pickWords(count: wordCount, using: &rng)
        let (solGrid, placed) = buildSolutionGrid(words: selected, using: &rng)

        guard placed.count >= 5 else { return generateFallback(seed: seed) }

        let scrambleMoves = Int.random(in: 8...15, using: &rng)
        var scrambled = solGrid
        for _ in 0..<scrambleMoves {
            scrambled = randomMove(using: &rng).apply(to: scrambled)
        }

        // Scramble until NO words are found in the initial state
        var scrambleAttempts = 0
        while scrambleAttempts < 20 {
            let anyFound = placed.contains { scrambled.findWord($0.word) != nil }
            if !anyFound { break }
            for _ in 0..<3 {
                scrambled = randomMove(using: &rng).apply(to: scrambled)
            }
            scrambleAttempts += 1
        }

        return ShiftPuzzle(
            id: -Int(seed), initialGrid: scrambled,
            targetWords: placed,
            solutionGrid: solGrid
        )
    }

    // MARK: - Word Selection (shorter words more common)

    private static func pickWords(count: Int, using rng: inout SeededRandomNumberGenerator) -> [String] {
        var pool: [String] = []

        // Weight: 3-letter ×4, 4-letter ×4, 5-letter ×3, 6-letter ×2, 7-letter ×1, 8-letter ×1
        pool += words3 + words3 + words3 + words3
        pool += words4 + words4 + words4 + words4
        pool += words5 + words5 + words5
        pool += words6 + words6
        pool += words7
        pool += words8

        pool.shuffle(using: &rng)

        var picked: [String] = []


        for word in pool {
            guard picked.count < count else { break }
            // Skip duplicates
            guard !picked.contains(word) else { continue }
            picked.append(word)
        }

        return picked
    }

    // MARK: - Solution Grid Builder

    private static func buildSolutionGrid(
        words: [String], using rng: inout SeededRandomNumberGenerator
    ) -> (ShiftGrid, [TargetWord]) {
        let size = ShiftGrid.size
        var grid = Array(repeating: Array(repeating: Character(" "), count: size), count: size)
        var placed: [TargetWord] = []
        let dirs: [WordDirection] = WordDirection.allCases

        for word in words {
            let chars = Array(word.uppercased())
            var ok = false
            var attempts = 0

            while !ok && attempts < 80 {
                attempts += 1
                let dir = dirs.randomElement(using: &rng)!
                let (dR, dC) = dir.delta

                let maxR = dir == .diagonalUp ? size - 1 : size - 1 - max(0, (chars.count - 1) * dR)
                let minR = dir == .diagonalUp ? max(0, chars.count - 1) : 0
                let maxC = size - 1 - max(0, (chars.count - 1) * dC)

                guard minR <= maxR, maxC >= 0 else { continue }

                let startR = Int.random(in: minR...maxR, using: &rng)
                let startC = Int.random(in: 0...maxC, using: &rng)

                var canPlace = true
                var r = startR, c = startC
                for ch in chars {
                    if grid[r][c] != " " && grid[r][c] != ch { canPlace = false; break }
                    r += dR; c += dC
                }

                if canPlace {
                    r = startR; c = startC
                    for ch in chars { grid[r][c] = ch; r += dR; c += dC }
                    placed.append(TargetWord(word: word.uppercased()))
                    ok = true
                }
            }
        }

        // Fill empty cells
        let fill: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for r in 0..<size {
            for c in 0..<size {
                if grid[r][c] == " " { grid[r][c] = fill.randomElement(using: &rng)! }
            }
        }

        return (ShiftGrid(letters: grid), placed)
    }

    // MARK: - Helpers

    private static func randomMove(using rng: inout SeededRandomNumberGenerator) -> ShiftMove {
        let t = Int.random(in: 0..<4, using: &rng)
        let i = Int.random(in: 0..<ShiftGrid.size, using: &rng)
        switch t {
        case 0: return .rowLeft(i)
        case 1: return .rowRight(i)
        case 2: return .columnUp(i)
        default: return .columnDown(i)
        }
    }

    private static func seedFromDate(_ date: Date) -> UInt64 {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return UInt64(c.year ?? 2024) * 10000 + UInt64(c.month ?? 1) * 100 + UInt64(c.day ?? 1)
    }

    private static func generateFallback(seed: UInt64) -> ShiftPuzzle {
        var rng = SeededRandomNumberGenerator(seed: seed &+ 999)
        let words = pickWords(count: 5, using: &rng)
        let (grid, placed) = buildSolutionGrid(words: words, using: &rng)
        let scrambled = randomMove(using: &rng).apply(to: grid)
        return ShiftPuzzle(id: -Int(seed), initialGrid: scrambled, targetWords: placed, solutionGrid: grid)
    }
}
