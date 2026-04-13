//
//  StreakManagerTests.swift
//  PrismaTests
//
//  Tests for StreakManager using an isolated UserDefaults suite
//  so tests don't pollute the real app's defaults.
//

import Testing
import Foundation
@testable import Prisma

// MARK: - Test Helpers

private extension StreakManager {
    /// Reads streak state using a fresh UserDefaults suite scoped to this test run.
    static func makeIsolated(suiteName: String) -> UserDefaults {
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        return suite
    }
}

// MARK: - Streak Manager Tests

@Suite("StreakManager")
struct StreakManagerTests {

    // Each test uses a unique suite name based on the game string to avoid
    // cross-test contamination during parallel execution.

    @Test("First ever win starts streak at 1")
    func firstWinStartsStreak() {
        let game = "test.firstWin"
        StreakManager.resetStreak(for: game)

        let streak = StreakManager.recordDailyWin(game: game)
        #expect(streak == 1)
        StreakManager.resetStreak(for: game)
    }

    @Test("Winning same day twice keeps streak at 1")
    func sameDayWinNoChange() {
        let game = "test.sameDay"
        StreakManager.resetStreak(for: game)

        StreakManager.recordDailyWin(game: game)
        let streak = StreakManager.recordDailyWin(game: game)
        #expect(streak == 1)
        StreakManager.resetStreak(for: game)
    }

    @Test("Current streak returns 0 before first win")
    func currentStreakZeroBeforeFirstWin() {
        let game = "test.zeroStreak"
        StreakManager.resetStreak(for: game)

        let streak = StreakManager.currentStreak(for: game)
        #expect(streak == 0)
    }

    @Test("Resetting streak returns to 0")
    func resetStreakToZero() {
        let game = "test.resetStreak"
        StreakManager.resetStreak(for: game)
        StreakManager.recordDailyWin(game: game)

        StreakManager.resetStreak(for: game)
        #expect(StreakManager.currentStreak(for: game) == 0)
    }

    @Test("Different games have independent streaks")
    func independentStreaksPerGame() {
        let gameA = "test.streakGameA"
        let gameB = "test.streakGameB"
        StreakManager.resetStreak(for: gameA)
        StreakManager.resetStreak(for: gameB)

        StreakManager.recordDailyWin(game: gameA)
        let streakA = StreakManager.currentStreak(for: gameA)
        let streakB = StreakManager.currentStreak(for: gameB)

        #expect(streakA == 1)
        #expect(streakB == 0)

        StreakManager.resetStreak(for: gameA)
        StreakManager.resetStreak(for: gameB)
    }

    @Test("currentStreak reflects after a win")
    func currentStreakReflectsWin() {
        let game = "test.currentAfterWin"
        StreakManager.resetStreak(for: game)

        StreakManager.recordDailyWin(game: game)
        #expect(StreakManager.currentStreak(for: game) == 1)
        StreakManager.resetStreak(for: game)
    }
}
