//
//  ProfileCustomizeSheet.swift
//  Prisma
//
//  Sheet allowing users to toggle which sections appear on the You tab.
//

import SwiftUI

struct ProfileCustomizeSheet: View {
    @Bindable var prefs: ProfileSectionPreferences
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
                            isOn: $prefs.showStatCards
                        )
                        SectionToggle(
                            title: "Daily Streaks",
                            subtitle: "Consecutive days played per game",
                            icon: "flame.fill",
                            color: .orange,
                            isOn: $prefs.showStreaks
                        )
                        SectionToggle(
                            title: "Daily History",
                            subtitle: "Calendar and list of past daily results",
                            icon: "calendar",
                            color: .purple,
                            isOn: $prefs.showDailyHistory
                        )
                    } header: {
                        Text("ESSENTIALS")
                            .font(.caption2.weight(.heavy).monospaced())
                            .kerning(1)
                    }

                    Section {
                        SectionToggle(
                            title: "Win Rate Chart",
                            subtitle: "Trend chart of your win percentage",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .green,
                            isOn: $prefs.showWinRateChart
                        )
                        SectionToggle(
                            title: "Solve Times",
                            subtitle: "Average solve duration per game",
                            icon: "stopwatch.fill",
                            color: .cyan,
                            isOn: $prefs.showSolveTimeStats
                        )
                        SectionToggle(
                            title: "Leaderboards",
                            subtitle: "Game Center leaderboard preview",
                            icon: "trophy.fill",
                            color: .yellow,
                            isOn: $prefs.showLeaderboards
                        )
                        SectionToggle(
                            title: "Badges",
                            subtitle: "Achievement badge collection",
                            icon: "star.circle.fill",
                            color: .pink,
                            isOn: $prefs.showBadges
                        )
                    } header: {
                        Text("EXTRAS")
                            .font(.caption2.weight(.heavy).monospaced())
                            .kerning(1)
                    } footer: {
                        Text("These sections are hidden by default. Turn them on when you're ready for more detail.")
                            .font(.caption)
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
                        .font(.body.weight(.semibold))
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
                    .font(.body.weight(.medium))
                    .foregroundStyle(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
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
