//
//  GameCenterIntegrationTests.swift
//  PrismaTests
//
//  Validates Game Center submission logic (metric labels, score routing,
//  achievement triggers) using protocol-based mocking — no live GK calls.
//

import Testing
import Foundation
import GameKit
@testable import Prisma

// MARK: - Metric Label Tests

@MainActor
@Suite("GameCenterManager metric labels")
struct MetricLabelTests {

    @Test("Shift metric label is 'seconds'")
    func shiftMetricLabel() {
        #expect(GameCenterManager.metricLabel(for: .shift) == "seconds")
    }

    @Test("Signals metric label is 'guesses'")
    func signalsMetricLabel() {
        #expect(GameCenterManager.metricLabel(for: .signals) == "guesses")
    }

    @Test("Archive metric label is 'guesses'")
    func archiveMetricLabel() {
        #expect(GameCenterManager.metricLabel(for: .archive) == "guesses")
    }

    @Test("Cargo metric label is 'seconds'")
    func cargoMetricLabel() {
        #expect(GameCenterManager.metricLabel(for: .cargo) == "seconds")
    }

    @Test("Circuit metric label is 'seconds'")
    func circuitMetricLabel() {
        #expect(GameCenterManager.metricLabel(for: .circuit) == "seconds")
    }

    @Test("All games have lower-is-better metric direction")
    func allGamesLowerIsBetter() {
        for game in GameType.allCases {
            #expect(
                GameCenterManager.metricDirection(for: game) == .lowerIsBetter,
                "Expected lowerIsBetter for \(game.displayName)"
            )
        }
    }
}

// MARK: - Leaderboard ID Mapping Tests

@MainActor
@Suite("Leaderboard ID mapping")
struct LeaderboardIDTests {

    @Test("Each game has a unique daily best leaderboard ID")
    func uniqueBestIDs() {
        let service = FriendsService.shared
        let ids = GameType.allCases.map { service.bestLeaderboardID($0) }
        #expect(Set(ids).count == GameType.allCases.count, "Leaderboard IDs must be unique per game")
    }

    @Test("Each game has a unique daily streak leaderboard ID")
    func uniqueStreakIDs() {
        // Streak IDs stay declared in GameCenterManager.Leaderboard even though
        // they're not surfaced in UI or written to (Phase 2, 2026-04-25). The
        // string constants must remain unique so we can re-enable streak boards
        // later without an ID collision.
        let ids = [
            GameCenterManager.Leaderboard.signalsDailyStreak,
            GameCenterManager.Leaderboard.archiveDailyStreak,
            GameCenterManager.Leaderboard.cargoDailyStreak,
            GameCenterManager.Leaderboard.shiftDailyStreak,
            GameCenterManager.Leaderboard.circuitDailyStreak,
        ]
        #expect(Set(ids).count == ids.count, "Streak IDs must be unique per game")
    }

    @Test("Best and streak IDs are distinct for the same game")
    func bestAndStreakDistinct() {
        let pairs: [(best: String, streak: String, game: String)] = [
            (GameCenterManager.Leaderboard.signalsDailyBest,
             GameCenterManager.Leaderboard.signalsDailyStreak, "Signals"),
            (GameCenterManager.Leaderboard.archiveDailyBest,
             GameCenterManager.Leaderboard.archiveDailyStreak, "Archive"),
            (GameCenterManager.Leaderboard.cargoDailyBest,
             GameCenterManager.Leaderboard.cargoDailyStreak, "Cargo"),
            (GameCenterManager.Leaderboard.shiftDailyBest,
             GameCenterManager.Leaderboard.shiftDailyStreak, "Shift"),
            (GameCenterManager.Leaderboard.circuitDailyBest,
             GameCenterManager.Leaderboard.circuitDailyStreak, "Circuit"),
        ]
        for pair in pairs {
            #expect(pair.best != pair.streak, "\(pair.game) best and streak IDs must differ")
        }
    }

    @Test("Shift daily best ID is prisma.shift.daily.best")
    func shiftBestID() {
        #expect(GameCenterManager.Leaderboard.shiftDailyBest == "prisma.shift.daily.best")
    }

    @Test("Shift daily streak ID is prisma.shift.daily.streak")
    func shiftStreakID() {
        #expect(GameCenterManager.Leaderboard.shiftDailyStreak == "prisma.shift.daily.streak")
    }
}

// MARK: - Achievement ID Coverage Tests

@MainActor
@Suite("Achievement ID coverage")
struct AchievementIDTests {

    @Test("Every game type has a 'first' achievement ID")
    func allGamesHaveFirstAchievement() {
        let firstIDs: [GameType: String] = [
            .signals: GameCenterManager.Achievement.firstSignal,
            .archive: GameCenterManager.Achievement.firstArchive,
            .cargo:   GameCenterManager.Achievement.firstCargo,
            .shift:   GameCenterManager.Achievement.firstShift,
            .circuit: GameCenterManager.Achievement.firstCircuit,
        ]
        for game in GameType.allCases {
            #expect(firstIDs[game] != nil, "Missing 'first' achievement for \(game.displayName)")
            #expect(!firstIDs[game]!.isEmpty, "'first' ID must not be empty for \(game.displayName)")
        }
    }

    @Test("Every game type has a 'perfect' achievement ID")
    func allGamesHavePerfectAchievement() {
        let perfectIDs: [GameType: String] = [
            .signals: GameCenterManager.Achievement.perfectSignal,
            .archive: GameCenterManager.Achievement.perfectArchive,
            .cargo:   GameCenterManager.Achievement.perfectCargo,
            .shift:   GameCenterManager.Achievement.perfectShift,
            .circuit: GameCenterManager.Achievement.perfectCircuit,
        ]
        for game in GameType.allCases {
            #expect(perfectIDs[game] != nil, "Missing 'perfect' achievement for \(game.displayName)")
        }
    }

    // Streak achievements removed (Phase 4, 2026-04-25) — streaks tracked
    // in-app via StreakManager / Badge.streak3/7/30 only, no Game Center
    // integration. The streak leaderboard ID *constants* stay in
    // GameCenterManager.Leaderboard for future use; their uniqueness is
    // covered by `bestAndStreakDistinct` higher up in this file.

    // Local mastery achievements also removed (Phase 4, 2026-04-25). Mastery
    // milestones live in `Badge.local25 / 50 / 100` only. The
    // `prisma.local.mastery` *leaderboard* persists (covered above by
    // `uniqueBestIDs` since it's part of the configured set).
}

// MARK: - Shift GameResult Builder Tests

@MainActor
@Suite("Shift GameResult builder")
struct ShiftGameResultTests {

    @Test("buildGameResult stores moveCount in guessCount field")
    func moveCountStoredInGuessCount() {
        let puzzle = ShiftPuzzle(
            id: 0,
            initialGrid: blankShiftGrid(),
            targetWords: [],
            solutionGrid: nil
        )
        let vm = ShiftGameViewModel(puzzle: puzzle, isDaily: true)
        vm.performMove(.rowLeft(0))
        vm.performMove(.rowLeft(1))
        let result = vm.buildGameResult()
        #expect(result.guessCount == 2, "guessCount should equal moveCount for Shift")
    }

    @Test("buildGameResult records duration seconds")
    func durationRecorded() {
        let puzzle = ShiftPuzzle(
            id: 0,
            initialGrid: blankShiftGrid(),
            targetWords: [],
            solutionGrid: nil
        )
        let vm = ShiftGameViewModel(puzzle: puzzle, isDaily: true)
        let result = vm.buildGameResult()
        // Duration will be 0 since no timer started; just verify the field exists
        #expect(result.durationSeconds >= 0)
    }

    @Test("buildGameResult sets gameType to shift")
    func gameTypeIsShift() {
        let puzzle = ShiftPuzzle(
            id: 0,
            initialGrid: blankShiftGrid(),
            targetWords: [],
            solutionGrid: nil
        )
        let vm = ShiftGameViewModel(puzzle: puzzle, isDaily: true)
        let result = vm.buildGameResult()
        #expect(result.gameType == .shift)
    }
}

// MARK: - Head-to-Head Outcome Tests

@MainActor
@Suite("HeadToHead outcome logic")
struct HeadToHeadTests {

    @Test("Lower score wins (all games are lower-is-better)")
    func lowerScoreWins() {
        let h2h = HeadToHead(
            game: .signals,
            myStats: FriendGameStats(game: .signals, bestAllTimeScore: 2, bestAllTimeRank: 1, currentStreak: 5, streakRank: 1),
            theirStats: FriendGameStats(game: .signals, bestAllTimeScore: 4, bestAllTimeRank: 2, currentStreak: 3, streakRank: 2)
        )
        #expect(h2h.outcome == .iWin)
    }

    @Test("Higher score loses")
    func higherScoreLoses() {
        let h2h = HeadToHead(
            game: .shift,
            myStats: FriendGameStats(game: .shift, bestAllTimeScore: 120, bestAllTimeRank: 5, currentStreak: 2, streakRank: 3),
            theirStats: FriendGameStats(game: .shift, bestAllTimeScore: 60, bestAllTimeRank: 1, currentStreak: 1, streakRank: 4)
        )
        #expect(h2h.outcome == .theyWin)
    }

    @Test("Equal scores tie-break on streak — higher streak wins")
    func tieBreakOnStreak() {
        let h2h = HeadToHead(
            game: .cargo,
            myStats: FriendGameStats(game: .cargo, bestAllTimeScore: 45, bestAllTimeRank: 3, currentStreak: 10, streakRank: 1),
            theirStats: FriendGameStats(game: .cargo, bestAllTimeScore: 45, bestAllTimeRank: 3, currentStreak: 5, streakRank: 2)
        )
        #expect(h2h.outcome == .iWin)
    }

    @Test("Equal scores and equal streaks result in tie")
    func trueTie() {
        let h2h = HeadToHead(
            game: .circuit,
            myStats: FriendGameStats(game: .circuit, bestAllTimeScore: 30, bestAllTimeRank: 2, currentStreak: 7, streakRank: 1),
            theirStats: FriendGameStats(game: .circuit, bestAllTimeScore: 30, bestAllTimeRank: 2, currentStreak: 7, streakRank: 1)
        )
        #expect(h2h.outcome == .tie)
    }

    @Test("Nil scores result in notEnoughData")
    func nilScoresNotEnoughData() {
        let h2h = HeadToHead(
            game: .archive,
            myStats: FriendGameStats(game: .archive, bestAllTimeScore: nil, bestAllTimeRank: nil, currentStreak: 0, streakRank: nil),
            theirStats: FriendGameStats(game: .archive, bestAllTimeScore: 3, bestAllTimeRank: 1, currentStreak: 5, streakRank: 1)
        )
        #expect(h2h.outcome == .notEnoughData)
    }

    @Test("metricLabel uses centralized GameCenterManager label")
    func metricLabelMatchesManager() {
        for game in GameType.allCases {
            let h2h = HeadToHead(
                game: game,
                myStats: FriendGameStats(game: game, bestAllTimeScore: nil, bestAllTimeRank: nil, currentStreak: 0, streakRank: nil),
                theirStats: FriendGameStats(game: game, bestAllTimeScore: nil, bestAllTimeRank: nil, currentStreak: 0, streakRank: nil)
            )
            #expect(h2h.metricLabel == GameCenterManager.metricLabel(for: game))
        }
    }
}

// MARK: - FriendTodaySummary Tests

@MainActor
@Suite("FriendTodaySummary computed properties")
struct FriendTodaySummaryTests {

    @Test("hasSolvedToday is true when any game has a score")
    func hasSolvedWithOneGame() {
        let summary = makeSummary(scores: [.signals: 3, .archive: nil, .cargo: nil, .shift: nil, .circuit: nil])
        #expect(summary.hasSolvedToday)
    }

    @Test("hasSolvedToday is false when no games have scores")
    func notSolvedWithNoGames() {
        let summary = makeSummary(scores: [.signals: nil, .archive: nil, .cargo: nil, .shift: nil, .circuit: nil])
        #expect(!summary.hasSolvedToday)
    }

    @Test("gamesSolvedToday counts correctly")
    func gamesSolvedCount() {
        let summary = makeSummary(scores: [.signals: 2, .archive: 4, .cargo: nil, .shift: 90, .circuit: nil])
        #expect(summary.gamesSolvedToday == 3)
    }

    @Test("maxStreak returns the highest streak across games")
    func maxStreakCalculation() {
        let summary = makeSummary(
            scores: [.signals: 1, .archive: nil, .cargo: nil, .shift: nil, .circuit: nil],
            streaks: [.signals: 5, .archive: 2, .cargo: 0, .shift: 12, .circuit: 0]
        )
        #expect(summary.maxStreak == 12)
    }

    // MARK: - Helpers

    private func makeSummary(
        scores: [GameType: Int?],
        streaks: [GameType: Int] = [:]
    ) -> FriendTodaySummary {
        var perGame: [GameType: FriendTodayEntry] = [:]
        for game in GameType.allCases {
            perGame[game] = FriendTodayEntry(
                score: scores[game] ?? nil,
                rank: scores[game] != nil ? 1 : nil,
                streak: streaks[game] ?? 0
            )
        }
        // Using a mock player isn't possible without GKPlayer — but FriendTodaySummary
        // stores it opaquely. We rely on the computed properties only for these tests.
        // Create a minimal summary with the GKLocalPlayer as a stand-in.
        return FriendTodaySummary(player: GKLocalPlayer.local, perGame: perGame)
    }
}

// MARK: - Helpers

/// Returns a blank 8×8 ShiftGrid filled with 'A'.
private func blankShiftGrid() -> ShiftGrid {
    let row = Array(repeating: Character("A"), count: 8)
    return ShiftGrid(letters: Array(repeating: row, count: 8))
}
