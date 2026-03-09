//
//  ContentView.swift
//  Prisma
//
//  Main entry point and Home screen.
//  Provides a TabView for Daily, Local, and Profile.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // Dark space background matching the game aesthetic
    private var bgColor: Color {
        Color(red: 0.05, green: 0.05, blue: 0.08)
    }

    var body: some View {
        TabView {
            Tab("Daily", systemImage: "sun.max.fill") {
                gameList(isDaily: true)
            }

            Tab("Local", systemImage: "folder.fill") {
                gameList(isDaily: false)
            }

            Tab("You", systemImage: "person.fill") {
                ProfileView()
            }
        }
        .tint(.white)
        .toolbarBackground(bgColor, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }

    // MARK: - Game List

    @ViewBuilder
    private func gameList(isDaily: Bool) -> some View {
        NavigationStack {
            ZStack {
                ZStack {
                    bgColor
                    RadialGradient(
                        colors: [Color(red: 0.15, green: 0.08, blue: 0.3).opacity(0.4), .clear],
                        center: .top, startRadius: 50, endRadius: 500
                    )
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection

                        Text(isDaily ? "DAILY PUZZLES" : "LOCAL ARCHIVE")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .kerning(1.5)
                            .padding(.horizontal, 24)

                        VStack(spacing: 16) {
                            GameCard(
                                game: .signals,
                                icon: "antenna.radiowaves.left.and.right",
                                color: Color(red: 0.24, green: 0.65, blue: 0.36),
                                isDaily: isDaily
                            )

                            GameCard(
                                game: .archive,
                                icon: "clock.arrow.circlepath",
                                color: Color(red: 0.24, green: 0.52, blue: 0.85),
                                isDaily: isDaily
                            )

                            GameCard(
                                game: .cargo,
                                icon: "shippingbox.fill",
                                color: Color(red: 1.00, green: 0.55, blue: 0.26),
                                isDaily: isDaily
                            )

                            GameCard(
                                game: .shift,
                                icon: "slider.horizontal.3",
                                color: Color(red: 0.65, green: 0.24, blue: 0.85),
                                isDaily: isDaily
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 32)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: GameCardValue.self) { value in
                if value.isDaily {
                    switch value.game {
                    case .signals: SignalsGameView()
                    case .archive: ArchiveGameView()
                    case .cargo: CargoGameView()
                    case .shift: ShiftGameView(puzzle: ShiftPuzzleGenerator.generateDailyPuzzle(for: .now), isDaily: true)
                    case .orbit: Text("Coming Soon")
                    }
                } else {
                    LevelSelectorView(game: value.game)
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prisma")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.65, green: 0.24, blue: 0.85),
                                 Color(red: 0.4, green: 0.6, blue: 1.0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            Text("Your daily cognitive signal.")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Game Card

struct GameCardValue: Hashable {
    let game: GameType
    let isDaily: Bool
}

struct GameCard: View {
    let game: GameType
    let icon: String
    let color: Color
    let isDaily: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var cardBg: Color {
        Color(white: 0.12)
    }

    var body: some View {
        NavigationLink(value: GameCardValue(game: game, isDaily: isDaily)) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 54, height: 54)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(game.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(game.description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Disabled Game Card

struct DisabledGameCard: View {
    let game: GameType
    let icon: String

    @Environment(\.colorScheme) private var colorScheme

    private var cardBg: Color {
        Color(white: 0.08)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 54, height: 54)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(game.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.6))

                    Text("SOON")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.2)))
                }

                Text(game.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.primary.opacity(0.02), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}


