//
//  BadgeManager.swift
//  Prisma
//
//  Evaluates badge unlock conditions against game data.
//  Stores unlock state in UserDefaults for lightweight persistence.
//

import Foundation
import SwiftData

@Observable @MainActor
final class BadgeManager {
    static let shared = BadgeManager()
    
    private let defaults = UserDefaults.standard
    
    /// Returns info for all badges with current unlock state.
    func allBadges() -> [BadgeInfo] {
        Badge.allCases.map { badge in
            BadgeInfo(
                badge: badge,
                isUnlocked: isUnlocked(badge),
                unlockedDate: unlockedDate(badge)
            )
        }
    }
    
    var unlockedCount: Int {
        Badge.allCases.filter { isUnlocked($0) }.count
    }
    
    var totalCount: Int {
        Badge.allCases.count
    }
    
    /// Check if a specific badge is unlocked.
    func isUnlocked(_ badge: Badge) -> Bool {
        defaults.bool(forKey: "badge.\(badge.rawValue).unlocked")
    }
    
    /// Get the date a badge was unlocked.
    func unlockedDate(_ badge: Badge) -> Date? {
        defaults.object(forKey: "badge.\(badge.rawValue).date") as? Date
    }
    
    /// Unlock a badge (idempotent — won't overwrite existing unlock date).
    private func unlock(_ badge: Badge) {
        guard !isUnlocked(badge) else { return }
        defaults.set(true, forKey: "badge.\(badge.rawValue).unlocked")
        defaults.set(Date.now, forKey: "badge.\(badge.rawValue).date")
    }
    
    /// Evaluate all badge conditions and return any newly unlocked badges.
    @discardableResult
    func evaluateAll(context: ModelContext) -> [Badge] {
        var newlyUnlocked: [Badge] = []
        
        let allProgress = fetchAllProgress(context: context)
        let allResults = fetchAllResults(context: context)
        
        // First Win — any game won
        if !isUnlocked(.firstWin) {
            if allProgress.contains(where: { $0.won }) || allResults.contains(where: { $0.score > 0 }) {
                unlock(.firstWin)
                newlyUnlocked.append(.firstWin)
            }
        }
        
        // Streak badges
        let streakGames = ["signals", "archive", "cargo", "shift"]
        let maxStreak = streakGames.map { StreakManager.currentStreak(for: $0) }.max() ?? 0
        
        for (badge, threshold) in [(Badge.streak3, 3), (.streak7, 7), (.streak30, 30)] {
            if !isUnlocked(badge) && maxStreak >= threshold {
                unlock(badge)
                newlyUnlocked.append(badge)
            }
        }
        
        // Perfect Signal — won Signals with 1 guess
        if !isUnlocked(.perfectSignal) {
            let signalsWins = allResults.filter { $0.gameTypeRaw == GameType.signals.rawValue && $0.score > 0 }
            if signalsWins.contains(where: { $0.guessCount == 1 }) {
                unlock(.perfectSignal)
                newlyUnlocked.append(.perfectSignal)
            }
        }
        
        // Speed Demon — any win under 30 seconds
        if !isUnlocked(.speedDemon) {
            if allResults.contains(where: { $0.score > 0 && $0.durationSeconds > 0 && $0.durationSeconds < 30 }) {
                unlock(.speedDemon)
                newlyUnlocked.append(.speedDemon)
            }
        }
        
        // Local mastery milestones
        let totalLocalWins = allProgress.filter { $0.won }.count
        for (badge, threshold) in [(Badge.local25, 25), (.local50, 50), (.local100, 100)] {
            if !isUnlocked(badge) && totalLocalWins >= threshold {
                unlock(badge)
                newlyUnlocked.append(badge)
            }
        }
        
        // Per-game mastery (all 100 local levels won)
        for (badge, game) in [(Badge.signalsMaster, GameType.signals), (.archiveMaster, .archive), (.cargoMaster, .cargo), (.shiftMaster, .shift)] {
            if !isUnlocked(badge) {
                let gameWins = allProgress.filter { $0.gameTypeRaw == game.rawValue && $0.won }.count
                if gameWins >= 100 {
                    unlock(badge)
                    newlyUnlocked.append(badge)
                }
            }
        }
        
        return newlyUnlocked
    }
    
    // MARK: - Data Fetching
    
    private func fetchAllProgress(context: ModelContext) -> [LevelProgress] {
        let descriptor = FetchDescriptor<LevelProgress>()
        return (try? context.fetch(descriptor)) ?? []
    }
    
    private func fetchAllResults(context: ModelContext) -> [GameResult] {
        let descriptor = FetchDescriptor<GameResult>()
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Reset all badges (for developer/testing use).
    func resetAll() {
        for badge in Badge.allCases {
            defaults.removeObject(forKey: "badge.\(badge.rawValue).unlocked")
            defaults.removeObject(forKey: "badge.\(badge.rawValue).date")
        }
    }
}
