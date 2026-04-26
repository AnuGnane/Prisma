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

    /// Processes a game result: saves to context, updates streaks, posts to Game Center,
    /// and fires all applicable achievements.
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

        // 3. Update Streaks and Game Center
        if result.score > 0 { // Won
            if result.isDaily {
                // StreakManager still records the win — it drives the in-app
                // You-tab streak UI. Anu chose to keep streaks app-only with no
                // Game Center integration (Phase 4, 2026-04-25), so the return
                // value is intentionally discarded.
                _ = StreakManager.recordDailyWin(game: result.gameTypeRaw)

                // Guard against duplicate GC submissions — e.g. if the result overlay
                // fires saveCompletionIfNeeded more than once (dismiss + re-enter).
                let gc = GameCenterManager.shared
                if gc.claimDailyGCSubmission(gameType: result.gameType) {
                    // Streak boards intentionally not written — they stay
                    // unconfigured in App Store Connect (Phase 2, 2026-04-25).
                    switch result.gameType {
                    case .signals:
                        gc.submitScore(result.guessCount, leaderboardIDs: [GameCenterManager.Leaderboard.signalsDailyBest])
                    case .archive:
                        gc.submitScore(result.guessCount, leaderboardIDs: [GameCenterManager.Leaderboard.archiveDailyBest])
                    case .cargo:
                        gc.submitScore(Int(result.durationSeconds), leaderboardIDs: [GameCenterManager.Leaderboard.cargoDailyBest])
                    case .shift:
                        gc.submitScore(Int(result.durationSeconds), leaderboardIDs: [GameCenterManager.Leaderboard.shiftDailyBest])
                    case .circuit:
                        gc.submitScore(Int(result.durationSeconds), leaderboardIDs: [GameCenterManager.Leaderboard.circuitDailyBest])
                    }
                    // Fire achievements tied to this daily win
                    reportAchievements(for: result, context: context)
                }
            }

            // Local Progress Mastery leaderboard (all modes). Local mastery
            // *achievements* (`local_25 / 50 / 100`) are intentionally not
            // reported — Anu opted to keep mastery milestones app-only via
            // `Badge.local25 / 50 / 100` (Phase 4, 2026-04-25). The
            // `localMastery` *leaderboard* itself stays — it's a real
            // configured ASC entry that ranks total wins across players.
            let allProgress = (try? context.fetch(FetchDescriptor<LevelProgress>())) ?? []
            let totalWon = allProgress.filter { $0.won }.count
            GameCenterManager.shared.submitScore(totalWon, leaderboardIDs: [GameCenterManager.Leaderboard.localMastery])
        }

        try? context.save()
    }

    // MARK: - Achievement Reporting

    /// Central achievement reporter called on every daily win.
    private func reportAchievements(for result: GameResult, context: ModelContext) {
        let gc = GameCenterManager.shared

        // ── First-game unlocks ────────────────────────────────────────────────
        // GC handles deduplication server-side (won't re-award 100% achievements).
        let firstAchievement: String? = switch result.gameType {
        case .signals: GameCenterManager.Achievement.firstSignal
        case .archive: GameCenterManager.Achievement.firstArchive
        case .cargo:   GameCenterManager.Achievement.firstCargo
        case .shift:   GameCenterManager.Achievement.firstShift
        case .circuit: GameCenterManager.Achievement.firstCircuit
        }
        if let id = firstAchievement { gc.reportAchievement(id) }

        // Streak milestone achievements removed — Anu opted to keep streaks
        // app-side only, with no Game Center integration (Phase 4, 2026-04-25).
        // The in-app streak UI is driven directly by StreakManager.

        // ── Perfect clears ────────────────────────────────────────────────────
        switch result.gameType {
        case .signals:
            // Solved with 1 guess
            if result.guessCount == 1 {
                gc.reportAchievement(GameCenterManager.Achievement.perfectSignal)
            }
        case .archive:
            // Identified the date on the first guess
            if result.guessCount == 1 {
                gc.reportAchievement(GameCenterManager.Achievement.perfectArchive)
            }
        case .cargo:
            // Perfect Cargo: only on 100% board fill (score >= 1000)
            if result.score >= 1000 {
                gc.reportAchievement(GameCenterManager.Achievement.perfectCargo)
            }
        case .shift:
            // Perfect Shift (all words, no undos) is signalled via score field:
            // ShiftViewModel sets score = 2 for a no-undo solve, 1 for normal win.
            if result.score >= 2 {
                gc.reportAchievement(GameCenterManager.Achievement.perfectShift)
            }
        case .circuit:
            // Perfect Circuit: solved at or under the par move count.
            // CircuitViewModel sets score = 2 for at/under par, 1 for normal win.
            if result.score >= 2 {
                gc.reportAchievement(GameCenterManager.Achievement.perfectCircuit)
            }
        }

        // Local mastery achievements removed — same rationale as streaks.
        // Mastery is celebrated in-app via `Badge.local25 / 50 / 100`
        // (granted by `BadgeManager`) instead of GC progress achievements.
    }
}
