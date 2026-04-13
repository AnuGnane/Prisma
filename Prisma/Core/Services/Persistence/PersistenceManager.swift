//
//  PersistenceManager.swift
//  Prisma
//
//  SwiftData-backed persistence for GameResult and LevelProgress records.
//
//  CLOUDKIT SYNC — HOW TO ENABLE:
//  1. In Xcode, select the Prisma target → Signing & Capabilities
//  2. Add the "iCloud" capability and create a container named "iCloud.com.anugnana.Prisma"
//  3. Add the "Background Modes" capability and tick "Remote notifications"
//  4. In the container configuration below, switch from `.none` to:
//       cloudKitDatabase: .private("iCloud.com.anugnana.Prisma")
//  5. Create the same container in the Apple Developer portal
//
//  CloudKit model constraints already satisfied:
//  - No @Attribute(.unique) / #Unique on any model property
//  - All model properties have default values or are optional
//  - All relationships are marked optional
//

import Foundation
import SwiftData

@MainActor
struct PersistenceManager {

    // MARK: - Container

    static let container: ModelContainer = {
        let schema = Schema([GameResult.self, LevelProgress.self])
        let storeURL = URL.applicationSupportDirectory.appending(path: "Prisma.store")

        // Local-only store. See file header for CloudKit migration steps.
        let config = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Migration failure (e.g. schema changed without versioning).
            // Delete the old store and rebuild from scratch — data loss is preferable to a crash.
            print("[Persistence] ModelContainer init failed (\(error)). Deleting store and retrying.")
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))

            // Also clean up any legacy default store location from earlier builds
            let defaultURL = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: defaultURL)
            try? FileManager.default.removeItem(at: defaultURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: defaultURL.appendingPathExtension("wal"))

            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("[Persistence] Cannot create ModelContainer even after deleting store: \(error)")
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

    // MARK: - Fetch daily result for a game on a given date

    static func fetchDailyResult(
        for gameType: GameType,
        on date: Date,
        context: ModelContext
    ) -> GameResult? {
        let raw = gameType.rawValue
        let descriptor = FetchDescriptor<GameResult>(
            predicate: #Predicate { $0.gameTypeRaw == raw && $0.isDaily == true },
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

    static func markLevelPlayed(gameType: GameType, levelId: Int, won: Bool, score: Int, guessesUsed: Int, durationSeconds: Double = 0, context: ModelContext) {
        let progressList = fetchLevelProgress(for: gameType, context: context)

        if progressList.contains(where: { $0.levelId == levelId }) {
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
            playedDate: .now,
            durationSeconds: durationSeconds
        )
        context.insert(newProgress)
        try? context.save()
    }

    static func isLevelPlayed(gameType: GameType, levelId: Int, context: ModelContext) -> Bool {
        let progressList = fetchLevelProgress(for: gameType, context: context)
        return progressList.contains(where: { $0.levelId == levelId && $0.isPlayed })
    }

    // MARK: - Total Local Wins (for Game Center mastery leaderboard)

    static func totalLocalWins(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<LevelProgress>()
        let allProgress = (try? context.fetch(descriptor)) ?? []
        return allProgress.filter(\.won).count
    }
}
