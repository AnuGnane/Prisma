//
//  ProfileCustomizeSheet.swift
//  Prisma
//
//  Sheet allowing users to toggle which sections appear on the You tab.
//

import SwiftUI

struct ProfileCustomizeSheet: View {
    let prefs: ProfileSectionPreferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground()

                List {
                    Section {
                        SectionToggle(
                            title: "Game Stats",
                            subtitle: "Win counts, progress bars, and averages",
                            icon: "chart.bar.fill",
                            color: .blue,
                            isOn: Binding(
                                get: { prefs.showStatCards },
                                set: { prefs.showStatCards = $0 }
                            )
                        )
                        SectionToggle(
                            title: "Daily Streaks",
                            subtitle: "Consecutive days played per game",
                            icon: "flame.fill",
                            color: .orange,
                            isOn: Binding(
                                get: { prefs.showStreaks },
                                set: { prefs.showStreaks = $0 }
                            )
                        )
                        SectionToggle(
                            title: "Daily History",
                            subtitle: "Calendar and list of past daily results",
                            icon: "calendar",
                            color: .purple,
                            isOn: Binding(
                                get: { prefs.showDailyHistory },
                                set: { prefs.showDailyHistory = $0 }
                            )
                        )
                    } header: {
                        Text("ESSENTIALS")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .kerning(1)
                    }

                    Section {
                        SectionToggle(
                            title: "Win Rate Chart",
                            subtitle: "Trend chart of your win percentage",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .green,
                            isOn: Binding(
                                get: { prefs.showWinRateChart },
                                set: { prefs.showWinRateChart = $0 }
                            )
                        )
                        SectionToggle(
                            title: "Solve Times",
                            subtitle: "Average solve duration per game",
                            icon: "stopwatch.fill",
                            color: .cyan,
                            isOn: Binding(
                                get: { prefs.showSolveTimeStats },
                                set: { prefs.showSolveTimeStats = $0 }
                            )
                        )
                        SectionToggle(
                            title: "Leaderboards",
                            subtitle: "Game Center leaderboard preview",
                            icon: "trophy.fill",
                            color: .yellow,
                            isOn: Binding(
                                get: { prefs.showLeaderboards },
                                set: { prefs.showLeaderboards = $0 }
                            )
                        )
                        SectionToggle(
                            title: "Badges",
                            subtitle: "Achievement badge collection",
                            icon: "star.circle.fill",
                            color: .pink,
                            isOn: Binding(
                                get: { prefs.showBadges },
                                set: { prefs.showBadges = $0 }
                            )
                        )
                    } header: {
                        Text("EXTRAS")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .kerning(1)
                    } footer: {
                        Text("These sections are hidden by default. Turn them on when you're ready for more detail.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }
}

// MARK: - Toggle Row

private struct SectionToggle: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(color)
    }
}

#Preview {
    ProfileCustomizeSheet(prefs: ProfileSectionPreferences.shared)
}
