//
//  StreakManager.swift
//  Prisma
//
//  Tracks daily win streaks using UserDefaults.
//  Each game type has its own independent streak counter.
//

import Foundation

struct StreakManager {
    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private static func lastWinDateKey(for game: String) -> String {
        "streak.\(game).lastWinDate"
    }

    private static func currentStreakKey(for game: String) -> String {
        "streak.\(game).current"
    }

    // MARK: - Public API

    /// Call this when the player wins a daily puzzle. Returns the updated streak count.
    @discardableResult
    static func recordDailyWin(game: String) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let lastWinDate = defaults.object(forKey: lastWinDateKey(for: game)) as? Date
        var currentStreak = defaults.integer(forKey: currentStreakKey(for: game))

        if let lastWin = lastWinDate {
            let lastWinDay = calendar.startOfDay(for: lastWin)
            let daysBetween = calendar.dateComponents([.day], from: lastWinDay, to: today).day ?? 0

            if daysBetween == 1 {
                // Consecutive day — extend streak
                currentStreak += 1
            } else if daysBetween == 0 {
                // Same day — no change (already counted)
                return currentStreak
            } else {
                // Missed a day — reset
                currentStreak = 1
            }
        } else {
            // First ever win
            currentStreak = 1
        }

        defaults.set(today, forKey: lastWinDateKey(for: game))
        defaults.set(currentStreak, forKey: currentStreakKey(for: game))
        return currentStreak
    }

    /// Returns the current streak for a game without modifying it.
    static func currentStreak(for game: String) -> Int {
        defaults.integer(forKey: currentStreakKey(for: game))
    }
}
