//
//  ProfileView.swift
//  Prisma
//
//  Displays the player's stats: local progress, daily history, streaks.
//  Designed as the "You" tab in the main TabView.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var allLevelProgress: [LevelProgress]
    @Query(sort: \GameResult.date, order: .reverse) private var allGameResults: [GameResult]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var badgeInfos: [BadgeInfo] = []
    @State private var newBadgeToast: Badge?
    @State private var showCustomize = false
    private var prefs = ProfileSectionPreferences.shared

    private var signalsProgress: [LevelProgress] {
        allLevelProgress.filter { $0.gameTypeRaw == GameType.signals.rawValue }
    }
    private var archiveProgress: [LevelProgress] {
        allLevelProgress.filter { $0.gameTypeRaw == GameType.archive.rawValue }
    }
    private var cargoProgress: [LevelProgress] {
        allLevelProgress.filter { $0.gameTypeRaw == GameType.cargo.rawValue }
    }
    private var shiftProgress: [LevelProgress] {
        allLevelProgress.filter { $0.gameTypeRaw == GameType.shift.rawValue }
    }
    private var dailyResults: [GameResult] {
        allGameResults.filter { $0.isDaily }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Section header
                        Text("YOUR STATS")
                            .font(.caption.weight(.heavy).monospaced())
                            .foregroundStyle(.secondary)
                            .kerning(2)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        // Game stat cards
                        if prefs.showStatCards {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    StatCard(
                                        game: .signals,
                                        icon: "antenna.radiowaves.left.and.right",
                                        accentColor: AppTheme.signals,
                                        progress: signalsProgress
                                    )
                                    StatCard(
                                        game: .archive,
                                        icon: "clock.arrow.circlepath",
                                        accentColor: AppTheme.archive,
                                        progress: archiveProgress
                                    )
                                }
                                HStack(spacing: 12) {
                                    StatCard(
                                        game: .cargo,
                                        icon: "shippingbox.fill",
                                        accentColor: AppTheme.cargo,
                                        progress: cargoProgress
                                    )
                                    StatCard(
                                        game: .shift,
                                        icon: "slider.horizontal.3",
                                        accentColor: AppTheme.shift,
                                        progress: shiftProgress
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Streak info
                        if prefs.showStreaks {
                            streakSection
                        }
                        
                        // Win rate trend chart
                        if prefs.showWinRateChart {
                            WinRateChartView()
                                .padding(.horizontal, 20)
                        }
                        
                        // Solve time stats
                        if prefs.showSolveTimeStats {
                            SolveTimeStatsView()
                                .padding(.horizontal, 20)
                        }

                        // Daily history
                        if prefs.showDailyHistory {
                            if !dailyResults.isEmpty {
                                dailyHistorySection
                            } else {
                                emptyDailySection
                            }
                        }

                        // Game Center placeholder
                        if prefs.showLeaderboards {
                            gameCenterPlaceholder
                        }
                        
                        // Achievement badges
                        if prefs.showBadges {
                            BadgeGridView(
                                badges: badgeInfos,
                                unlockedCount: BadgeManager.shared.unlockedCount,
                                totalCount: BadgeManager.shared.totalCount
                            )
                            .padding(.horizontal, 20)
                        }
                        
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showCustomize = true
                        } label: {
                            Label("Customize", systemImage: "slider.horizontal.3")
                                .font(.callout)
                                .foregroundStyle(.primary.opacity(0.5))
                        }
                        .accessibilityLabel("Customize profile")
                        .accessibilityHint("Opens profile customization options")
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                                .font(.callout)
                                .foregroundStyle(.primary.opacity(0.5))
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Opens app settings")
                    }
                }
            }
            .sheet(isPresented: $showCustomize) {
                ProfileCustomizeSheet(prefs: prefs)
            }
            .onAppear {
                evaluateBadges()
            }
            .overlay(alignment: .top) {
                if let badge = newBadgeToast {
                    badgeToast(badge)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 60)
                }
            }
        }
    }
    
    private func evaluateBadges() {
        let newlyUnlocked = BadgeManager.shared.evaluateAll(context: modelContext)
        badgeInfos = BadgeManager.shared.allBadges()
        
        if let first = newlyUnlocked.first {
            if reduceMotion {
                newBadgeToast = first
            } else {
                withAnimation(.spring(response: 0.5)) {
                    newBadgeToast = first
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(3))
                if reduceMotion {
                    newBadgeToast = nil
                } else {
                    withAnimation { newBadgeToast = nil }
                }
            }
        }
    }
    
    private func badgeToast(_ badge: Badge) -> some View {
        HStack(spacing: 10) {
            Image(systemName: badge.iconName)
                .font(.title3.weight(.medium))
                .foregroundStyle(badge.accentColor)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Badge Unlocked!")
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundStyle(.primary.opacity(0.5))
                Text(badge.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.12))
                .overlay(Capsule().strokeBorder(badge.accentColor.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DAILY STREAKS")

            HStack(spacing: 12) {
                StreakPill(
                    label: "Signals",
                    streak: StreakManager.currentStreak(for: "signals"),
                    color: AppTheme.signals
                )
                StreakPill(
                    label: "Archive",
                    streak: StreakManager.currentStreak(for: "archive"),
                    color: AppTheme.archive
                )
            }
            HStack(spacing: 12) {
                StreakPill(
                    label: "Cargo",
                    streak: StreakManager.currentStreak(for: "cargo"),
                    color: AppTheme.cargo
                )
                StreakPill(
                    label: "Shift",
                    streak: StreakManager.currentStreak(for: "shift"),
                    color: AppTheme.shift
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Daily History Section

    private var dailyHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("RECENT DAILY RESULTS")

            DailyCalendarView()
                .padding(.bottom, 8)

            VStack(spacing: 1) {
                ForEach(Array(dailyResults.prefix(20)), id: \.persistentModelID) { result in
                    NavigationLink {
                        PastDailyResultView(result: result)
                    } label: {
                        DailyResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 20)
    }

    private var emptyDailySection: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.stars.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No daily puzzles played yet")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Complete your first daily puzzle to see results here.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
    }

    // MARK: - Game Center Leaderboards

    private var gameCenterPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("LEADERBOARDS")

            NavigationLink(destination: LeaderboardView()) {
                HStack(spacing: 14) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow.opacity(0.8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Game Center")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Rankings & Friends leaderboards")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Helper

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.heavy).monospaced())
            .foregroundStyle(.secondary)
            .kerning(1.5)
    }
    
}

// MARK: - Stat Card

private struct StatCard: View {
    let game: GameType
    let icon: String
    let accentColor: Color
    let progress: [LevelProgress]

    private var won: Int { progress.filter { $0.won }.count }
    private var played: Int { progress.filter { $0.isPlayed }.count }
    private var winRate: Double { played > 0 ? Double(won) / Double(played) : 0 }
    private var avgGuesses: Double {
        let wins = progress.filter { $0.won }
        guard !wins.isEmpty else { return 0 }
        return Double(wins.reduce(0) { $0 + $1.guessesUsed }) / Double(wins.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(accentColor)
                Text(game.displayName)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            // Big stat
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(won)")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(accentColor)
                    Text("/ 100")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text("levels won")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Progress bar — using ProgressView avoids GeometryReader
            ProgressView(value: Double(won), total: 100)
                .progressViewStyle(.linear)
                .tint(accentColor)

            // Secondary stats
            HStack {
                miniStat(label: "Win %", value: played > 0 ? "\(Int(winRate * 100))%" : "—")
                Spacer()
                miniStat(label: "Avg", value: avgGuesses > 0 ? avgGuesses.formatted(.number.precision(.fractionLength(1))) : "—")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary.opacity(0.12)))
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Streak Pill

private struct StreakPill: View {
    let label: String
    let streak: Int
    let color: Color

    @State private var flamePulse = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if streak >= 3 {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(color.opacity(0.3))
                        .blur(radius: 6)
                        .scaleEffect(flamePulse ? 1.3 : 1.0)
                }

                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(streak > 0 ? color : Color.secondary.opacity(0.4))
                    .scaleEffect(streak >= 3 && flamePulse ? 1.08 : 1.0)
            }
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: flamePulse)
            .onAppear {
                if streak >= 3 { flamePulse = true }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(streak)")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(streak > 0 ? color : .secondary)
                Text("\(label) streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.12)))
        .overlay(
            streak >= 3 ?
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(color.opacity(flamePulse ? 0.2 : 0.05), lineWidth: 1)
                : nil
        )
    }
}

// MARK: - Daily Result Row

private struct DailyResultRow: View {
    let result: GameResult

    private var gameColor: Color {
        switch result.gameType {
        case .signals: return AppTheme.signals
        case .archive: return AppTheme.archive
        case .cargo:   return AppTheme.cargo
        case .shift:   return AppTheme.shift
        }
    }

    private var formattedDate: String {
        result.date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Win/loss indicator
            Circle()
                .fill(result.score > 0 ? gameColor : Color.secondary.opacity(0.3))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.gameType.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if result.gameType == .cargo {
                Text(result.shareString)
                    .font(.caption.weight(.medium).monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if result.score > 0 {
                Text("\(result.guessCount) guesses")
                    .font(.callout.weight(.medium).monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Text("Lost")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.12))
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}
