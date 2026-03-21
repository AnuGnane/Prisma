//
//  GameDetailView.swift
//  Prisma
//
//  Intermediate screen shown when tapping a game card on the home feed.
//  Provides hero card, Play Daily button, and Levels access.
//

import SwiftUI
import SwiftData

// MARK: - Navigation Destinations

enum GameDetailRoute: Hashable {
    case playDaily(GameType)
    case levels(GameType)
}

struct GameDetailView: View {
    let game: GameType
    let modelContext: ModelContext

    @Query private var progressList: [LevelProgress]
    @Environment(\.dismiss) private var dismiss

    init(game: GameType, modelContext: ModelContext) {
        self.game = game
        self.modelContext = modelContext
        let raw = game.rawValue
        _progressList = Query(filter: #Predicate<LevelProgress> { $0.gameTypeRaw == raw })
    }

    private var gameColor: Color { AppTheme.accent(for: game) }
    private var wonCount: Int { progressList.filter(\.won).count }
    private var totalPlayed: Int { progressList.filter(\.isPlayed).count }
    private var winRate: Int {
        guard totalPlayed > 0 else { return 0 }
        return Int(Double(wonCount) / Double(totalPlayed) * 100)
    }
    private var dailyStreak: Int { StreakManager.currentStreak(for: game.rawValue) }

    private var todayString: String {
        Date.now.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        ZStack {
            AppTheme.appBackground()

            ScrollView {
                VStack(spacing: 24) {
                    GameDetailHeroCard(game: game, todayString: todayString)
                    GameDetailActionButtons(game: game)
                    GameDetailStatsSection(
                        wonCount: wonCount,
                        totalPlayed: totalPlayed,
                        winRate: winRate,
                        dailyStreak: dailyStreak,
                        gameColor: gameColor
                    )
                    GameDetailHowToPlaySection(game: game, gameColor: gameColor, howToPlaySteps: howToPlaySteps)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(for: GameDetailRoute.self) { route in
            switch route {
            case .playDaily(let gameType):
                DailyGameDestinationInternal(gameType: gameType, modelContext: modelContext)
            case .levels(let gameType):
                LevelSelectorView(game: gameType)
            }
        }
    }

    // MARK: - How to Play Steps

    private var howToPlaySteps: [String] {
        switch game {
        case .signals:
            return [
                "Guess the secret 4-digit code",
                "After each guess, you'll see which digits are correct and in the right position",
                "Use logic to narrow down the code in as few guesses as possible"
            ]
        case .archive:
            return [
                "Guess the historic date shown in the clue",
                "Enter day, month, and year for each guess",
                "Feedback shows which parts are correct or close"
            ]
        case .cargo:
            return [
                "Place all the pieces to fill the grid completely",
                "Drag, rotate, and flip pieces to find the right fit",
                "Every cell must be covered — no gaps or overlaps"
            ]
        case .shift:
            return [
                "Slide rows and columns to spell hidden words",
                "Each move shifts an entire row or column",
                "Find all the words in as few moves as possible"
            ]
        case .orbit:
            return ["Coming soon"]
        }
    }
}

// MARK: - Subviews

struct GameDetailHeroCard: View {
    let game: GameType
    let todayString: String

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                GameCardGraphic(game: game)
                    .frame(width: 80, height: 80)

                Text(game.displayName)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(game.description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            Text(todayString)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: AppTheme.gradient(for: game),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct GameDetailActionButtons: View {
    let game: GameType

    var body: some View {
        VStack(spacing: 12) {
            NavigationLink(value: GameDetailRoute.playDaily(game)) {
                Text("Play Daily")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: AppTheme.gradient(for: game),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            NavigationLink(value: GameDetailRoute.levels(game)) {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("Levels")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppTheme.keyFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

struct GameDetailStatsSection: View {
    let wonCount: Int
    let totalPlayed: Int
    let winRate: Int
    let dailyStreak: Int
    let gameColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR STATS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)
                .kerning(1.5)

            HStack(spacing: 0) {
                statItem(value: "\(wonCount)", label: "Won")
                divider
                statItem(value: totalPlayed > 0 ? "\(winRate)%" : "—", label: "Win Rate")
                divider
                statItem(value: "\(dailyStreak)", label: "Streak")
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppTheme.keyFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(gameColor)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 36)
    }
}

struct GameDetailHowToPlaySection: View {
    let game: GameType
    let gameColor: Color
    let howToPlaySteps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW TO PLAY")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)
                .kerning(1.5)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(howToPlaySteps, id: \.self) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(gameColor)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(step)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.keyFill)
            )
        }
    }
}

// MARK: - Internal Daily Destination

private struct DailyGameDestinationInternal: View {
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
    NavigationStack {
        GameDetailView(
            game: .signals,
            modelContext: try! ModelContext(ModelContainer(for: LevelProgress.self, GameResult.self))
        )
    }
}
