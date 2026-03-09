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
    @Environment(\.modelContext) private var modelContext
    @State private var showResetAlert = false
    @State private var resetGameType: GameType?

    private let games: [(GameType, String, String, Color)] = [
        (.signals, "Signals", "antenna.radiowaves.left.and.right", Color(red: 0.24, green: 0.65, blue: 0.36)),
        (.archive, "Archive", "clock.arrow.circlepath", Color(red: 0.24, green: 0.52, blue: 0.85)),
        (.cargo,   "Cargo",   "shippingbox.fill", Color(red: 1.00, green: 0.55, blue: 0.26)),
        (.shift,   "Shift",   "slider.horizontal.3", Color(red: 0.65, green: 0.24, blue: 0.85))
    ]

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.10).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    sectionLabel("PREFERENCES")

                    settingsCard {
                        Toggle(isOn: $hapticsEnabled) {
                            Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .tint(Color(red: 0.65, green: 0.24, blue: 0.85))

                        Divider().background(Color.white.opacity(0.06))

                        Toggle(isOn: $soundEnabled) {
                            Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .tint(Color(red: 0.65, green: 0.24, blue: 0.85))
                    }

                    sectionLabel("RESET PROGRESS")

                    settingsCard {
                        ForEach(Array(games.enumerated()), id: \.offset) { index, game in
                            if index > 0 {
                                Divider().background(Color.white.opacity(0.06))
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
                                        .foregroundStyle(.white)
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
                                .font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.10), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white.opacity(0.3))
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
