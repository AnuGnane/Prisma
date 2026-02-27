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
        let schema = Schema([GameResult.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    // MARK: - Save

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
}
