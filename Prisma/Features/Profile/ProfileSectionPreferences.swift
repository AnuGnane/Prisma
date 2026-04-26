//
//  ProfileSectionPreferences.swift
//  Prisma
//
//  User-configurable visibility for each section on the "You" tab.
//  Backed by @AppStorage so preferences persist across launches.
//

import SwiftUI

/// Keys and defaults for each togglable section on the Profile/You tab.
@Observable @MainActor
final class ProfileSectionPreferences {
    static let shared = ProfileSectionPreferences()

    private init() {
        // One-shot: remove the legacy "profile.showLeaderboards" key that
        // governed the old Game Center placeholder on the You tab. The
        // placeholder has been removed — the Leaderboard now lives in its
        // own tab. Harmless no-op on fresh installs.
        UserDefaults.standard.removeObject(forKey: "profile.showLeaderboards")
    }

    // Sections ON by default
    var showStatCards: Bool {
        get { UserDefaults.standard.object(forKey: "profile.showStatCards") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "profile.showStatCards") }
    }
    var showStreaks: Bool {
        get { UserDefaults.standard.object(forKey: "profile.showStreaks") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "profile.showStreaks") }
    }
    var showDailyHistory: Bool {
        get { UserDefaults.standard.object(forKey: "profile.showDailyHistory") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "profile.showDailyHistory") }
    }

    // Sections OFF by default
    var showWinRateChart: Bool {
        get { UserDefaults.standard.object(forKey: "profile.showWinRateChart") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "profile.showWinRateChart") }
    }
    var showSolveTimeStats: Bool {
        get { UserDefaults.standard.object(forKey: "profile.showSolveTimeStats") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "profile.showSolveTimeStats") }
    }
    var showBadges: Bool {
        get { UserDefaults.standard.object(forKey: "profile.showBadges") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "profile.showBadges") }
    }
}

