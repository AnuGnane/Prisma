//
//  CircuitLevelGenerator.swift
//  Prisma
//
//  Provides deterministic picking of curated levels for daily play.
//  Replaced earlier procedural algorithm to guarantee 100% solvable space-filling puzzles.
//

import Foundation

// MARK: - Daily Level Picker

struct CircuitLevelGenerator {

    /// Loads the curated list and picks a daily level deterministically based on the date.
    static func generate(for date: Date = .now) -> CircuitLevel {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        
        let allLevels = CircuitLevelLoader.load()
        guard !allLevels.isEmpty else {
            fatalError("No levels available in circuit_levels.json")
        }
        
        // Use a hash of the year and day to reliably select the daily index
        let combined = year * 1000 + dayOfYear
        let dailyIndex = abs(combined) % allLevels.count
        
        let baseLevel = allLevels[dailyIndex]
        
        // Return the exact curated level, but assign it a deterministic daily negative ID
        // so that daily challenge saves don't conflict with progression arc saves.
        return CircuitLevel(
            id: -combined,
            size: baseLevel.size,
            seed: combined, // Unused by picker, but stored for parity
            grid: baseLevel.grid,
            terminalPairs: baseLevel.terminalPairs,
            solutionStateJSON: baseLevel.solutionStateJSON
        )
    }
}
