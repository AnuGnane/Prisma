//
//  PersistenceManager.swift
//  Prisma
//
//  SwiftData-backed persistence for GameResult records.
//  Inject via .modelContainer(PersistenceManager.container) in PrismaApp.
//

import Foundation
import SwiftData

@MainActor
struct PersistenceManager {
    static let container: ModelContainer = {
        let schema = Schema([GameResult.self, LevelProgress.self])
        
        // Define a specific URL for the store so we can delete it if migration fails
        let storeURL = URL.applicationSupportDirectory.appending(path: "Prisma.store")
        let config = ModelConfiguration(schema: schema, url: storeURL)
        
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("SwiftData schema mismatch or load failure. Deleting old store and recreating...")
            
            // Delete the named store
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            
            // Also clean up the default store from earlier builds
            let defaultURL = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: defaultURL)
            try? FileManager.default.removeItem(at: defaultURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: defaultURL.appendingPathExtension("wal"))
            
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to recreate ModelContainer: \(error)")
            }
        }
    }()

    // MARK: - Save GameResult

    static func save(_ result: GameResult, context: ModelContext) {
        context.insert(result)
        try? context.save()
    }

    // MARK: - Fetch latest result for a game on a given date

    static func fetchResult(
        for gameType: GameType,
        on date: Date,
        context: ModelContext
    ) -> GameResult? {
        let raw = gameType.rawValue
        let descriptor = FetchDescriptor<GameResult>(
            predicate: #Predicate { $0.gameTypeRaw == raw },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let results = (try? context.fetch(descriptor)) ?? []
        return results.first { date.isSameDay(as: $0.date) }
    }

    // MARK: - Fetch all results for a game (most recent first)

    static func fetchAll(
        for gameType: GameType,
        context: ModelContext
    ) -> [GameResult] {
        let raw = gameType.rawValue
        let descriptor = FetchDescriptor<GameResult>(
            predicate: #Predicate { $0.gameTypeRaw == raw },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Level Progress

    static func fetchLevelProgress(for gameType: GameType, context: ModelContext) -> [LevelProgress] {
        let raw = gameType.rawValue
        let descriptor = FetchDescriptor<LevelProgress>(
            predicate: #Predicate { $0.gameTypeRaw == raw },
            sortBy: [SortDescriptor(\.levelId, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func markLevelPlayed(gameType: GameType, levelId: Int, won: Bool, score: Int, guessesUsed: Int, context: ModelContext) {
        let progressList = fetchLevelProgress(for: gameType, context: context)
        
        if let existing = progressList.first(where: { $0.levelId == levelId }) {
            // Already played — don't overwrite
            return
        }
        
        let newProgress = LevelProgress(
            gameTypeRaw: gameType.rawValue,
            levelId: levelId,
            isPlayed: true,
            won: won,
            score: score,
            guessesUsed: guessesUsed,
            playedDate: .now
        )
        context.insert(newProgress)
        try? context.save()
    }

    static func isLevelPlayed(gameType: GameType, levelId: Int, context: ModelContext) -> Bool {
        let progressList = fetchLevelProgress(for: gameType, context: context)
        return progressList.contains(where: { $0.levelId == levelId && $0.isPlayed })
    }
}
