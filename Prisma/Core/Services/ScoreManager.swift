//
//  ScoreManager.swift
//  Prisma
//
//  Centralizes saving game results, updating streaks, and integrating with Game Center.
//

import SwiftData
import Foundation

@MainActor
final class ScoreManager {
    static let shared = ScoreManager()
    
    /// Processes a game result: saves to context, updates streaks, and posts to Game Center safely.
    func processAndSaveResult(_ result: GameResult, context: ModelContext) {
        // 1. Context Insertion
        if result.isDaily {
            if PersistenceManager.fetchDailyResult(for: result.gameType, on: result.date, context: context) == nil {
                context.insert(result)
            }
        } else {
            context.insert(result)
        }
        
        // 2. Mark local progression
        if let levelId = result.levelId {
            let won = result.score > 0
            PersistenceManager.markLevelPlayed(
                gameType: result.gameType,
                levelId: levelId,
                won: won,
                score: result.score,
                guessesUsed: result.guessCount,
                durationSeconds: result.durationSeconds,
                context: context
            )
        }
        
        // 3. Update Streaks and Game Center natively cross-game
        if result.score > 0 { // Won
            if result.isDaily {
                let currentStreak = StreakManager.recordDailyWin(game: result.gameTypeRaw)
                
                let gc = GameCenterManager.shared
                switch result.gameType {
                case .signals:
                    gc.submitScore(result.guessCount, leaderboardIDs: [GameCenterManager.Leaderboard.signalsDailyBest])
                    gc.submitScore(currentStreak, leaderboardIDs: [GameCenterManager.Leaderboard.signalsDailyStreak])
                case .archive:
                    gc.submitScore(result.guessCount, leaderboardIDs: [GameCenterManager.Leaderboard.archiveDailyBest])
                    gc.submitScore(currentStreak, leaderboardIDs: [GameCenterManager.Leaderboard.archiveDailyStreak])
                case .cargo:
                    gc.submitScore(Int(result.durationSeconds), leaderboardIDs: [GameCenterManager.Leaderboard.cargoDailyBest])
                    gc.submitScore(currentStreak, leaderboardIDs: [GameCenterManager.Leaderboard.cargoDailyStreak])
                case .shift:
                    gc.submitScore(result.guessCount, leaderboardIDs: [GameCenterManager.Leaderboard.shiftDailyBest])
                    gc.submitScore(currentStreak, leaderboardIDs: [GameCenterManager.Leaderboard.shiftDailyStreak])
                case .circuit:
                    // Circuit uses time as the primary efficiency metric
                    gc.submitScore(Int(result.durationSeconds), leaderboardIDs: [])
                    gc.submitScore(currentStreak, leaderboardIDs: [])
                }
            }
            
            // Local Progress Mastery (abstracted to one single ping for all game modes)
            let allProgress = (try? context.fetch(FetchDescriptor<LevelProgress>())) ?? []
            let totalWon = allProgress.filter { $0.won }.count
            GameCenterManager.shared.submitScore(totalWon, leaderboardIDs: [GameCenterManager.Leaderboard.localMastery])
        }
        
        try? context.save()
    }
}
