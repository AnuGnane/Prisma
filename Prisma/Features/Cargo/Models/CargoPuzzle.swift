//
//  CargoPuzzle.swift
//  Prisma
//
//  Defines a single puzzle: grid dimensions, blocked cells, and the set of pieces.
//  Loaded from cargo_puzzles.json for local levels or generated procedurally for daily.
//

import Foundation

// MARK: - Puzzle Definition

struct CargoPuzzle: Codable, Identifiable {
    let id: Int
    let gridRows: Int
    let gridCols: Int
    let blockedCells: [CellCoord]
    let pieces: [CargoPiece]

    /// Total cells the player must fill
    var fillableCells: Int {
        gridRows * gridCols - blockedCells.count
    }

    /// Total cells across all pieces — should == fillableCells for a perfect puzzle
    var totalPieceCells: Int {
        pieces.reduce(0) { $0 + $1.baseCells.count }
    }

    var isPerfect: Bool { fillableCells == totalPieceCells }
}

// MARK: - Loader

struct CargoPuzzleLoader {
    private static var cache: [CargoPuzzle]?

    static func load() -> [CargoPuzzle] {
        if let cached = cache { return cached }

        guard let url = Bundle.main.url(forResource: "cargo_puzzles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let puzzles = try? JSONDecoder().decode([CargoPuzzle].self, from: data)
        else {
            print("[Cargo] Failed to load cargo_puzzles.json")
            return []
        }
        cache = puzzles
        return puzzles
    }

    static func puzzle(for level: Int) -> CargoPuzzle? {
        let puzzles = load()
        return puzzles.first { $0.id == level }
    }

    /// Daily puzzle — seeded from day of year
    static func dailyPuzzle(for date: Date = .now) -> CargoPuzzle? {
        let puzzles = load()
        guard !puzzles.isEmpty else { return nil }
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = (dayOfYear - 1) % puzzles.count
        return puzzles[index]
    }
}
