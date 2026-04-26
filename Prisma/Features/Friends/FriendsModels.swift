//
//  FriendsModels.swift
//  Prisma
//
//  Data types for the Friends tab social layer.
//  All values sourced from Game Center leaderboard entries — no cross-user CloudKit reads.
//
//  Phase 2 (2026-04-25) removed all streak-derived fields. Streak boards stay
//  unconfigured in App Store Connect (locked decision in
//  LEADERBOARD_RESTRUCTURE_PLAN.md §2), so reading them produced empty results
//  and unused UI affordances. The local player's own streak is still tracked
//  via `StreakManager` for the You-tab UI and the in-app streak badges —
//  but it is no longer surfaced for friends.
//
//  Phase 4 (2026-04-25) removed the GC streak achievements entirely. Streaks
//  are app-only. See `Core/Models/Badge.swift` for the in-app streak badges.
//

import GameKit

// MARK: - FriendTodayEntry

/// A single game's today-scope data for a friend, derived from the `daily.best`
/// leaderboard entries. Nil score / rank means they haven't played that game today.
struct FriendTodayEntry {
    let score: Int?
    let rank: Int?
}

// MARK: - FriendTodaySummary

/// Aggregated today-status for one friend across all five Prisma games.
struct FriendTodaySummary {
    let player: GKPlayer
    /// Per-game today data. Always contains all five GameType keys after loading.
    let perGame: [GameType: FriendTodayEntry]

    /// True if the friend has submitted a score in at least one game today.
    var hasSolvedToday: Bool {
        perGame.values.contains { $0.score != nil }
    }

    /// Number of games the friend has solved today (0–5).
    var gamesSolvedToday: Int {
        perGame.values.filter { $0.score != nil }.count
    }
}

// MARK: - FriendGameStats

/// All-time stats for a friend in a single game — used in FriendProfileView.
struct FriendGameStats {
    let game: GameType
    /// Best score on the `daily.best` all-time leaderboard, nil if never played.
    let bestAllTimeScore: Int?
    /// Rank on the all-time best leaderboard.
    let bestAllTimeRank: Int?
}

// MARK: - HeadToHead

/// Comparison of two players' all-time best performance in one game.
struct HeadToHead {
    let game: GameType
    let myStats: FriendGameStats
    let theirStats: FriendGameStats

    enum Outcome {
        case iWin, theyWin, tie, notEnoughData
    }

    /// Determines the head-to-head winner.
    ///
    /// All five games use lower-is-better scoring (guess count, move count, or
    /// elapsed seconds). A nil score means the player hasn't submitted any
    /// result for that game.
    var outcome: Outcome {
        guard let mine = myStats.bestAllTimeScore,
              let theirs = theirStats.bestAllTimeScore else {
            return .notEnoughData
        }
        if mine < theirs  { return .iWin }
        if theirs < mine  { return .theyWin }
        return .tie
    }

    /// Human-readable description of the metric being compared.
    var metricLabel: String {
        GameCenterManager.metricLabel(for: game)
    }
}
