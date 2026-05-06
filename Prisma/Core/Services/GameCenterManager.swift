//
//  GameCenterManager.swift
//  Prisma
//
//  Handles Game Center authentication, score submission at the end of each game,
//  and achievement reporting.
//
//  Key design decisions:
//  • Submission queue: scores/achievements are buffered while GK auth is pending,
//    then drained automatically when authentication succeeds. This prevents the
//    silent-drop bug where a score submitted milliseconds after app-launch (before
//    the async auth callback fires) would be lost forever.
//  • GC dedup guard: `submittedDailyGameIDs` tracks which daily game types have
//    had their GC scores submitted today, preventing duplicate submissions when
//    `saveCompletionIfNeeded` fires more than once.
//

import GameKit
import Observation

@Observable @MainActor
final class GameCenterManager: @unchecked Sendable {
    static let shared = GameCenterManager()

    // MARK: - State

    private(set) var isAuthenticated = false
    private(set) var playerName: String?

    // MARK: - Submission Queue
    //
    // Buffers pending GC calls that arrived while authentication was still in
    // progress. Drained immediately when isAuthenticated flips to true.

    private enum PendingSubmission {
        case score(Int, [String])
        case achievement(String, Double)
    }
    private var pendingSubmissions: [PendingSubmission] = []

    // MARK: - Daily GC Dedup
    //
    // Tracks which (gameType, calendarDay) pairs have already had a GC score
    // submitted. Persisted to UserDefaults so it survives app termination.
    // Entries from previous calendar days are pruned on launch.

    private static let submittedDailyKeysKey = "GC_submittedDailyKeys"

    private var submittedDailyKeys: Set<String> = {
        let stored = UserDefaults.standard.stringArray(forKey: submittedDailyKeysKey) ?? []
        // Prune entries from previous calendar days
        let todayPrefix = {
            let cal = Calendar.current
            let day = cal.dateComponents([.year, .month, .day], from: .now)
            return "\(day.year!)-\(day.month!)-\(day.day!)"
        }()
        return Set(stored.filter { $0.hasSuffix(todayPrefix) })
    }()

    /// Returns `true` and records the key if this is the first GC submission for
    /// this game type today. Returns `false` on subsequent calls.
    func claimDailyGCSubmission(gameType: GameType) -> Bool {
        let cal = Calendar.current
        let day = cal.dateComponents([.year, .month, .day], from: .now)
        let key = "\(gameType.rawValue)-\(day.year!)-\(day.month!)-\(day.day!)"
        if submittedDailyKeys.contains(key) { return false }
        submittedDailyKeys.insert(key)
        UserDefaults.standard.set(Array(submittedDailyKeys), forKey: Self.submittedDailyKeysKey)
        return true
    }

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
    //
    // App Store Connect configuration: all IDs below must exist as achievements
    // in App Store Connect → Your App → Features → Game Center → Achievements.
    // The five `first_*` entries are configured in ASC. The five `perfect_*`
    // entries and the three `local_*` progress achievements are tracked in
    // LEADERBOARD_RESTRUCTURE_TASKS.md § Phase 4 — they fire from the app and
    // silently no-op until the matching ASC entries land.
    //
    // Streaks are intentionally app-only — see Phase 4 decision log
    // (2026-04-25). `StreakManager` drives the in-app You-tab streak UI; there
    // are no streak achievements or streak leaderboards in Game Center.

    enum Achievement {
        // First-game unlocks (one per game, non-repeatable)
        static let firstSignal   = "prisma.first_signal"
        static let firstArchive  = "prisma.first_archive"
        static let firstCargo    = "prisma.first_cargo"
        static let firstShift    = "prisma.first_shift"
        static let firstCircuit  = "prisma.first_circuit"

        // Perfect clears (best possible result per game, non-repeatable)
        static let perfectSignal  = "prisma.perfect_signal"   // Signals solved in 1 guess
        static let perfectArchive = "prisma.perfect_archive"  // Archive solved in 1 guess
        static let perfectCargo   = "prisma.perfect_cargo"    // Cargo board fully packed
        static let perfectShift   = "prisma.perfect_shift"    // Shift — all words, no undos
        static let perfectCircuit = "prisma.perfect_circuit"  // Circuit solved at/under par

        // Local mastery achievements removed in Phase 4 (2026-04-25). The
        // milestones live entirely in-app via `Badge.local25 / 50 / 100`,
        // granted by `BadgeManager` based on `totalWon` thresholds. The
        // `prisma.local.mastery` *leaderboard* remains — it ranks total
        // local wins across players and is configured in App Store Connect.
    }

    // MARK: - Metric Direction
    // Used by head-to-head comparison and leaderboard display.

    enum MetricDirection {
        case lowerIsBetter  // Signals/Archive use guess count; Shift/Cargo/Circuit use seconds
        case higherIsBetter // Reserved — not currently used
    }

    static func metricDirection(for game: GameType) -> MetricDirection {
        .lowerIsBetter  // all five games: lower score = better performance
    }

    static func metricLabel(for game: GameType) -> String {
        switch game {
        case .signals, .archive:          return "guesses"
        case .shift, .cargo, .circuit:    return "seconds"
        }
    }

    // MARK: - Authentication

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            // Capture values on the calling thread, then update @MainActor state safely.
            let authenticated = GKLocalPlayer.local.isAuthenticated
            let name = GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.displayName : nil

            if let error {
                print("[GameCenter] Auth error: \(error.localizedDescription)")
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasAuthenticated = self.isAuthenticated
                self.isAuthenticated = authenticated
                self.playerName = name

                if authenticated && !wasAuthenticated {
                    print("[GameCenter] Authenticated as \(name ?? "unknown") — draining \(self.pendingSubmissions.count) queued submissions")
                    await self.drainPendingSubmissions()
                    #if DEBUG
                    await self.runVisibilityProbe()
                    #endif
                } else if !authenticated {
                    print("[GameCenter] Not authenticated yet (viewController pending: \(viewController != nil))")
                }
            }
        }
    }

    #if DEBUG
    /// One-shot diagnostic that prints which leaderboards and achievements
    /// GameKit can actually see for the running app. Run once after auth.
    ///
    /// Apple's `loadLeaderboards()` (no IDs) returns *every* leaderboard
    /// currently visible to the local player for this app. If it returns 0,
    /// the leaderboards configured in ASC are not yet "live" for this app
    /// version — typically because the app version hasn't been approved by
    /// App Store / Beta App Review yet, or sandbox state is stale.
    private func runVisibilityProbe() async {
        do {
            let allBoards = try await GKLeaderboard.loadLeaderboards()
            let ids = allBoards.map { $0.baseLeaderboardID }.sorted()
            print("[GameCenter] PROBE: \(allBoards.count) leaderboards visible to GameKit: \(ids)")
        } catch {
            print("[GameCenter] PROBE: loadLeaderboards() failed: \(error.localizedDescription)")
        }
        do {
            let allAchievements = try await GKAchievementDescription.loadAchievementDescriptions()
            let ids = allAchievements.map { $0.identifier }.sorted()
            print("[GameCenter] PROBE: \(allAchievements.count) achievements visible to GameKit: \(ids)")
        } catch {
            print("[GameCenter] PROBE: loadAchievementDescriptions() failed: \(error.localizedDescription)")
        }
    }
    #endif

    // MARK: - Score Submission

    /// Submit a score to one or more leaderboards.
    /// If not yet authenticated, the call is queued and retried after auth succeeds.
    func submitScore(_ score: Int, leaderboardIDs: [String]) {
        guard isAuthenticated else {
            pendingSubmissions.append(.score(score, leaderboardIDs))
            print("[GameCenter] Queued score \(score) for \(leaderboardIDs) (not yet authenticated)")
            return
        }
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
    /// If not yet authenticated, the call is queued and retried after auth succeeds.
    func reportAchievement(_ achievementID: String, percentComplete: Double = 100.0) {
        guard isAuthenticated else {
            pendingSubmissions.append(.achievement(achievementID, percentComplete))
            print("[GameCenter] Queued achievement \(achievementID) (not yet authenticated)")
            return
        }
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

    // MARK: - Private

    private func drainPendingSubmissions() async {
        guard isAuthenticated else { return }
        let pending = pendingSubmissions
        pendingSubmissions.removeAll()

        for item in pending {
            switch item {
            case let .score(score, ids):
                submitScore(score, leaderboardIDs: ids)
            case let .achievement(id, percent):
                reportAchievement(id, percentComplete: percent)
            }
        }
    }
}
