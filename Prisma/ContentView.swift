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
    @Environment(\.colorScheme) private var colorScheme

    // Adaptive background: dark in dark mode, light in light mode
    private var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.07, green: 0.07, blue: 0.10)
            : Color(.systemGroupedBackground)
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
        .tint(colorScheme == .dark ? .white : .primary)
        .toolbarBackground(bgColor, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    // MARK: - Game List

    @ViewBuilder
    private func gameList(isDaily: Bool) -> some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection

                        Text(isDaily ? "DAILY PUZZLES" : "LOCAL ARCHIVE")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .kerning(1.5)
                            .padding(.horizontal, 24)

                        VStack(spacing: 16) {
                            GameCard(
                                game: .signals,
                                icon: "antenna.radiowaves.left.and.right",
                                color: Color(red: 0.24, green: 0.65, blue: 0.36),
                                destination: isDaily ? AnyView(SignalsGameView()) : AnyView(LevelSelectorView(game: .signals))
                            )

                            GameCard(
                                game: .archive,
                                icon: "clock.arrow.circlepath",
                                color: Color(red: 0.24, green: 0.52, blue: 0.85),
                                destination: isDaily ? AnyView(ArchiveGameView()) : AnyView(LevelSelectorView(game: .archive))
                            )

                            GameCard(
                                game: .cargo,
                                icon: "shippingbox.fill",
                                color: Color(red: 1.00, green: 0.55, blue: 0.26),
                                destination: isDaily ? AnyView(CargoGameView()) : AnyView(LevelSelectorView(game: .cargo))
                            )

                            DisabledGameCard(game: .shift, icon: "slider.horizontal.3")
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prisma")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)

            Text("Your daily cognitive signal.")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Game Card

struct GameCard: View {
    let game: GameType
    let icon: String
    let color: Color
    let destination: AnyView

    @Environment(\.colorScheme) private var colorScheme

    private var cardBg: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color(.secondarySystemGroupedBackground)
    }

    var body: some View {
        NavigationLink(destination: destination.navigationBarBackButtonHidden(false).tint(color)) {
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
    }
}

// MARK: - Disabled Game Card

struct DisabledGameCard: View {
    let game: GameType
    let icon: String

    @Environment(\.colorScheme) private var colorScheme

    private var cardBg: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(.tertiarySystemGroupedBackground)
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


