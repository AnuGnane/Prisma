//
//  SettingsView.swift
//  Prisma
//
//  App settings: haptics, sound, theme, per-game progress reset.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("settings.hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("settings.soundEnabled") private var soundEnabled = true
    @AppStorage("settings.appearanceMode") private var appearanceMode = AppearanceMode.dark.rawValue
    @Environment(\.modelContext) private var modelContext
    @State private var showResetAlert = false
    @State private var resetGameType: GameType?

    private let games: [(GameType, String, String, Color)] = [
        (.signals, "Signals", "antenna.radiowaves.left.and.right", AppTheme.signals),
        (.archive, "Archive", "clock.arrow.circlepath", AppTheme.archive),
        (.cargo,   "Cargo",   "shippingbox.fill", AppTheme.cargo),
        (.shift,   "Shift",   "slider.horizontal.3", AppTheme.shift)
    ]

    var body: some View {
        ZStack {
            AppTheme.backgroundSecondary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    sectionLabel("PREFERENCES")

                    settingsCard {
                        Toggle(isOn: $hapticsEnabled) {
                            Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .tint(AppTheme.shift)

                        Divider().background(Color.primary.opacity(0.06))

                        Toggle(isOn: $soundEnabled) {
                            Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .tint(AppTheme.shift)
                    }

                    sectionLabel("APPEARANCE")

                    settingsCard {
                        HStack(spacing: 0) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        appearanceMode = mode.rawValue
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: mode.icon)
                                            .font(.system(size: 18))
                                        Text(mode.rawValue)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(appearanceMode == mode.rawValue ? AppTheme.shift.opacity(0.2) : Color.clear)
                                    )
                                    .foregroundStyle(appearanceMode == mode.rawValue ? AppTheme.shift : .secondary)
                                }
                            }
                        }
                    }

                    sectionLabel("RESET PROGRESS")

                    settingsCard {
                        ForEach(Array(games.enumerated()), id: \.offset) { index, game in
                            if index > 0 {
                                Divider().background(Color.primary.opacity(0.06))
                            }
                            Button {
                                resetGameType = game.0
                                showResetAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: game.2)
                                        .font(.system(size: 14))
                                        .foregroundStyle(game.3)
                                        .frame(width: 28)
                                    Text("Reset \(game.1)")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.red.opacity(0.5))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    sectionLabel("ABOUT")

                    settingsCard {
                        HStack {
                            Text("Version")
                                .font(.system(size: 15, weight: .medium)).foregroundStyle(.primary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.backgroundSecondary, for: .navigationBar)
        
        .alert("Reset Progress?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                if let type = resetGameType {
                    resetProgress(for: type)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete all local level progress for \(resetGameType?.displayName ?? "this game"). Daily results are kept.")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.3))
            .kerning(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }

    private func resetProgress(for gameType: GameType) {
        let raw = gameType.rawValue
        let predicate = #Predicate<LevelProgress> { $0.gameTypeRaw == raw }
        do {
            try modelContext.delete(model: LevelProgress.self, where: predicate)
        } catch {
            print("⚠️ Failed to reset \(gameType.displayName) progress: \(error)")
        }
        // Also reset streak
        StreakManager.resetStreak(for: gameType.rawValue)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}
