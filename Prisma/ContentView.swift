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
            Tab("Games", systemImage: "house.fill") {
                GamesHomeView()
            }

            Tab("Friends", systemImage: "person.2.fill") {
                FriendsPlaceholderView()
            }

            Tab("You", systemImage: "person.fill") {
                ProfileView()
            }
        }
        .tint(.primary)
        .toolbarBackground(AppTheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

// MARK: - Games Home (Unified Feed)

struct GamesHomeView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection

                        VStack(spacing: 16) {
                            ForEach([GameType.signals, .archive, .cargo, .shift], id: \.self) { game in
                                GameHeroCard(game: game)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Footer tagline
                        Text("Life is more fun with puzzles. ✨")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.25))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                    }
                    .padding(.vertical, 32)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: GameDetailDestination.self) { dest in
                GameDetailView(game: dest.game, modelContext: modelContext)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prisma")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: AppTheme.brandGradient,
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            Text(greetingText)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.8))

            Text("Four games. One daily challenge each.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary.opacity(0.4))
        }
        .padding(.horizontal, 24)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        case 17..<22: return "Good evening."
        default: return "Good night."
        }
    }
}

// MARK: - Game Detail Destination

struct GameDetailDestination: Hashable {
    let game: GameType
}

// MARK: - Game Hero Card (NYT-Style)

struct GameHeroCard: View {
    let game: GameType
    @State private var isPressed = false

    private var gameGradient: [Color] { AppTheme.gradient(for: game) }
    private var gameColor: Color { AppTheme.accent(for: game) }

    private var todayString: String {
        Date.now.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        NavigationLink(value: GameDetailDestination(game: game)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(game.displayName)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text(game.description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                    }

                    Spacer()

                    GameCardGraphic(game: game)
                        .frame(width: 72, height: 72)
                        .padding(.top, 4)
                }

                Spacer(minLength: 20)

                Text(todayString)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: gameGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(isPressed ? 0.3 : 0.1), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(CardPressStyle(isPressed: $isPressed))
    }
}

// MARK: - Card Press Button Style (scroll-friendly)

struct CardPressStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Game Card Graphic (mini game illustration)

struct GameCardGraphic: View {
    let game: GameType

    var body: some View {
        switch game {
        case .signals:  SignalsGraphic()
        case .archive:  ArchiveGraphic()
        case .cargo:    CargoGraphic()
        case .shift:    ShiftGraphic()
        case .orbit:    Image(systemName: "circle.dotted.circle")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// Signals: Mastermind code-guess board
private struct SignalsGraphic: View {
    // 5 rows of guesses: each row has 4 circle dots
    let rows: [[Color?]] = [
        [nil, nil, nil, nil],
        [.green, nil, nil, nil],
        [.green, .yellow, nil, nil],
        [.green, .green, .yellow, nil],
        [.green, .green, .green, .green],
    ]

    var body: some View {
        VStack(spacing: 5) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 5) {
                    ForEach(0..<4, id: \.self) { c in
                        let color = rows[r][c]
                        Circle()
                            .fill(color ?? Color.white.opacity(0.2))
                            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
    }
}

// Archive: Calendar grid with a circled date
private struct ArchiveGraphic: View {
    var body: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
                let days = ["S","M","T","W","T","F","S"]
                ForEach(days.indices, id: \.self) { i in
                    Text(days[i])
                        .font(.system(size: 5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            // Date grid — 5 rows, 7 cols
            let dates: [[Int?]] = [
                [1,2,3,4,5,6,7],
                [8,9,10,11,12,13,14],
                [15,16,17,18,19,20,21],
                [22,23,24,25,26,27,28],
                [29,30,31,nil,nil,nil,nil]
            ]
            let highlighted = 16

            VStack(spacing: 2) {
                ForEach(dates.indices, id: \.self) { r in
                    HStack(spacing: 2) {
                        ForEach(dates[r].indices, id: \.self) { c in
                            if let d = dates[r][c] {
                                ZStack {
                                    if d == highlighted {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 1)
                                    }
                                    Text("\(d)")
                                        .font(.system(size: 6, weight: d == highlighted ? .bold : .regular))
                                        .foregroundStyle(.white.opacity(d == highlighted ? 1.0 : 0.55))
                                }
                                .frame(width: 8, height: 8)
                            } else {
                                Color.clear.frame(width: 8, height: 8)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 72, height: 72)
    }
}

// Cargo: Tetromino grid
private struct CargoGraphic: View {
    // 4x4 grid, each cell has a colour index (0 = empty, 1-4 = piece)
    let grid: [[Int]] = [
        [1, 1, 2, 2],
        [1, 3, 3, 2],
        [4, 3, 4, 4],
        [4, 3, 4, 0],
    ]
    let colours: [Color] = [
        .clear,
        .white.opacity(0.9),
        .white.opacity(0.6),
        .white.opacity(0.75),
        .white.opacity(0.45),
    ]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(grid.indices, id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(grid[r].indices, id: \.self) { c in
                        let idx = grid[r][c]
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colours[idx])
                            .frame(width: 14, height: 14)
                    }
                }
            }
        }
    }
}

// Shift: Sliding letter-tile grid (3x4, one tile shifted)
private struct ShiftGraphic: View {
    let letters: [[String]] = [
        ["S","H","I","F"],
        ["T","E","R","M"],
        ["W","O","R","D"],
    ]
    let highlightRow = 0

    var body: some View {
        VStack(spacing: 3) {
            ForEach(letters.indices, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(letters[r].indices, id: \.self) { c in
                        let letter = letters[r][c]
                        let isHighlighted = (r == highlightRow)
                        ZStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white.opacity(isHighlighted ? 0.3 : 0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(.white.opacity(isHighlighted ? 0.6 : 0.25), lineWidth: 1)
                                )
                            Text(letter)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 15, height: 15)
                    }
                    // Arrow on the right of highlighted row
                    if r == highlightRow {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }
}

// MARK: - Friends Placeholder

struct FriendsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground()

                VStack(spacing: 20) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.primary.opacity(0.25))

                    Text("Follow your friends'\ndaily results.")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Track scores, streaks, and solve times\nacross all Prisma games.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                        .multilineTextAlignment(.center)

                    Text("COMING SOON")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.4))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 40)
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Keep DailyGameDestination for routing

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


