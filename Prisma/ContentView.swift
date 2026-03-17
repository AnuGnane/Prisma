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
    @Environment(\.modelContext) private var modelContext

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
        .tint(.primary)
        .toolbarBackground(AppTheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    // MARK: - Game List

    @ViewBuilder
    private func gameList(isDaily: Bool) -> some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection

                        Text(isDaily ? "DAILY PUZZLES" : "LOCAL ARCHIVE")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.4))
                            .kerning(1.5)
                            .padding(.horizontal, 24)

                        VStack(spacing: 16) {
                            GameCard(
                                game: .signals,
                                icon: "antenna.radiowaves.left.and.right",
                                color: AppTheme.signals,
                                isDaily: isDaily
                            )

                            GameCard(
                                game: .archive,
                                icon: "clock.arrow.circlepath",
                                color: AppTheme.archive,
                                isDaily: isDaily
                            )

                            GameCard(
                                game: .cargo,
                                icon: "shippingbox.fill",
                                color: AppTheme.cargo,
                                isDaily: isDaily
                            )

                            GameCard(
                                game: .shift,
                                icon: "slider.horizontal.3",
                                color: AppTheme.shift,
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
                    DailyGameDestination(gameType: value.game, modelContext: modelContext)
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
                        colors: [AppTheme.shift,
                                 AppTheme.cascadeBlue],
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            Text("Your daily cognitive signal.")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary.opacity(0.5))
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
    @State private var isPressed = false
    @Query private var progressList: [LevelProgress]
    
    init(game: GameType, icon: String, color: Color, isDaily: Bool) {
        self.game = game
        self.icon = icon
        self.color = color
        self.isDaily = isDaily
        let raw = game.rawValue
        _progressList = Query(filter: #Predicate<LevelProgress> { $0.gameTypeRaw == raw })
    }

    private var cardBg: Color {
        AppTheme.keyFill
    }
    
    private var wonCount: Int { progressList.filter(\.won).count }

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
                    
                    if !isDaily {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(color)
                                    .frame(width: max(0, geo.size.width * CGFloat(wonCount) / 100), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 2)
                    }
                }

                Spacer()

                if !isDaily && wonCount > 0 {
                    Text("\(wonCount)%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .padding(.trailing, 4)
                }
                
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
                    .fill(color.opacity(isPressed ? 0.08 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(color.opacity(isPressed ? 0.3 : 0.0), lineWidth: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Disabled Game Card

struct DisabledGameCard: View {
    let game: GameType
    let icon: String

    @Environment(\.colorScheme) private var colorScheme

    private var cardBg: Color {
        Color.primary.opacity(0.08)
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

// MARK: - Daily Game Destination (checks for already-played)

private struct DailyGameDestination: View {
    let gameType: GameType
    let modelContext: ModelContext

    var body: some View {
        if let existing = PersistenceManager.fetchDailyResult(for: gameType, on: .now, context: modelContext) {
            DailyCompletedView(result: existing)
        } else {
            switch gameType {
            case .signals: SignalsGameView()
            case .archive: ArchiveGameView()
            case .cargo: CargoGameView()
            case .shift: ShiftGameView(puzzle: ShiftPuzzleGenerator.generateDailyPuzzle(for: .now), isDaily: true)
            case .orbit: Text("Coming Soon")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}


