//
//  GameCenterManager.swift
//  Prisma
//
//  Handles Game Center authentication, score submission at the end of each game,
//  and achievement reporting.
//

import GameKit
import Observation

@Observable @MainActor
final class GameCenterManager: @unchecked Sendable {
    static let shared = GameCenterManager()

    // MARK: - State

    private(set) var isAuthenticated = false
    private(set) var playerName: String?

    // MARK: - Leaderboard IDs

    enum Leaderboard {
        static let signalsDailyStreak  = "prisma.signals.daily.streak"
        static let signalsDailyBest    = "prisma.signals.daily.best"
        static let archiveDailyStreak  = "prisma.archive.daily.streak"
        static let archiveDailyBest    = "prisma.archive.daily.best"
        static let cargoDailyStreak    = "prisma.cargo.daily.streak"
        static let cargoDailyBest      = "prisma.cargo.daily.best"
        static let shiftDailyStreak    = "prisma.shift.daily.streak"
        static let shiftDailyBest      = "prisma.shift.daily.best"
        static let circuitDailyStreak  = "prisma.circuit.daily.streak"
        static let circuitDailyBest    = "prisma.circuit.daily.best"
        static let localMastery        = "prisma.local.mastery"
    }

    // MARK: - Achievement IDs

    enum Achievement {
        static let firstSignal   = "prisma.first_signal"
        static let firstArchive  = "prisma.first_archive"
        static let streak3       = "prisma.streak_3"
        static let streak7       = "prisma.streak_7"
        static let streak30      = "prisma.streak_30"
        static let perfectSignal = "prisma.perfect_signal"
        static let local25       = "prisma.local_25"
        static let local50       = "prisma.local_50"
        static let local100      = "prisma.local_100"
    }

    // MARK: - Authentication

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let error {
                print("[GameCenter] Auth error: \(error.localizedDescription)")
                self?.isAuthenticated = false
                return
            }

            if viewController != nil {
                // Player needs to sign in — iOS will present automatically
                return
            }

            let player = GKLocalPlayer.local
            self?.isAuthenticated = player.isAuthenticated
            self?.playerName = player.isAuthenticated ? player.displayName : nil

            if player.isAuthenticated {
                print("[GameCenter] Authenticated successfully")
            }
        }
    }

    // MARK: - Score Submission

    /// Submit a score to one or more leaderboards.
    func submitScore(_ score: Int, leaderboardIDs: [String]) {
        guard isAuthenticated else { return }
        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: leaderboardIDs
                )
                print("[GameCenter] Score \(score) submitted to \(leaderboardIDs)")
            } catch {
                print("[GameCenter] Score submission failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Achievement Reporting

    /// Report one or more achievements. `percentComplete` should be 100 for a one-time unlock.
    func reportAchievement(_ achievementID: String, percentComplete: Double = 100.0) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: achievementID)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true

        Task {
            do {
                try await GKAchievement.report([achievement])
                print("[GameCenter] Achievement \(achievementID) reported")
            } catch {
                print("[GameCenter] Achievement report failed: \(error.localizedDescription)")
            }
        }
    }

    /// Helper: report progress achievements (e.g. 25/100 local levels = 25%)
    func reportProgressAchievement(_ achievementID: String, current: Int, target: Int) {
        let percent = min(100.0, Double(current) / Double(target) * 100.0)
        reportAchievement(achievementID, percentComplete: percent)
    }
}
