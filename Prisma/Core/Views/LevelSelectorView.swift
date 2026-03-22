//
//  LevelSelectorView.swift
//  Prisma
//
//  Reusable level selector for offline progression.
//  All 30 levels are accessible. Each level gets one attempt.
//  Played levels show won (⭐) or lost (✗) state and are disabled.
//

import SwiftUI
import SwiftData

struct LevelSelectorView: View {
    let game: GameType
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var progressList: [LevelProgress]
    @Query private var gameResults: [GameResult]
    
    init(game: GameType) {
        self.game = game
        let raw = game.rawValue
        _progressList = Query(filter: #Predicate<LevelProgress> { $0.gameTypeRaw == raw })
        _gameResults = Query(filter: #Predicate<GameResult> { $0.gameTypeRaw == raw && $0.isDaily == false })
    }
    
    // MARK: - Aggregate Stats
    
    private var playedCount: Int { progressList.filter(\.isPlayed).count }
    private var wonCount: Int { progressList.filter(\.won).count }
    
    // MARK: - Helper to find GameResult for a level
    
    private func gameResult(for levelId: Int) -> GameResult? {
        // Find GameResult by levelId (much more reliable than date matching)
        return gameResults.first { result in
            result.levelId == levelId
        }
    }
    
    var body: some View {
        ZStack {
            AppTheme.appBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    LevelSelectorHeader(iconForGame: iconForGame, colorForGame: colorForGame)
                    LevelSelectorStatsBar(
                        playedCount: playedCount,
                        wonCount: wonCount,
                        colorForGame: colorForGame
                    )
                    levelGrid
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(game.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - Navigation Routes

    enum LevelSelectorRoute: Hashable {
        case play(Int)
        case solution(Int)
    }
    
    // MARK: - Grid
    
    private var levelGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(1...100, id: \.self) { levelId in
                let progress = progressList.first(where: { $0.levelId == levelId })
                let isPlayed = progress?.isPlayed ?? false
                
                if isPlayed {
                    NavigationLink(value: LevelSelectorRoute.solution(levelId)) {
                        LevelSelectorPlayedCell(
                            levelId: levelId,
                            won: progress?.won ?? false,
                            score: progress?.score ?? 0,
                            guessesUsed: progress?.guessesUsed ?? 0,
                            durationSeconds: progress?.durationSeconds ?? 0,
                            colorForGame: colorForGame
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(value: LevelSelectorRoute.play(levelId)) {
                        LevelSelectorUnplayedCell(levelId: levelId)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .navigationDestination(for: LevelSelectorRoute.self) { route in
            switch route {
            case .play(let levelId):
                destination(for: levelId)
            case .solution(let levelId):
                let progress = progressList.first(where: { $0.levelId == levelId })
                LocalLevelSolutionView(
                    game: game,
                    levelId: levelId,
                    won: progress?.won ?? false,
                    score: progress?.score ?? 0,
                    gameResult: gameResult(for: levelId)
                )
            }
        }
    }
    
    // MARK: - Helpers
    
    private var iconForGame: String {
        switch game {
        case .signals: return "antenna.radiowaves.left.and.right"
        case .archive: return "clock.arrow.circlepath"
        case .cargo:   return "shippingbox.fill"
        case .shift:   return "slider.horizontal.3"
        case .orbit:   return "record.circle"
        }
    }
    
    private var colorForGame: Color {
        switch game {
        case .signals: return AppTheme.signals
        case .archive: return AppTheme.archive
        case .cargo:   return Color(red: 0.85, green: 0.52, blue: 0.24)
        case .shift:   return AppTheme.shift
        case .orbit:   return Color(red: 0.85, green: 0.24, blue: 0.52)
        }
    }
    
    @ViewBuilder
    private func destination(for levelId: Int) -> some View {
        switch game {
        case .signals:
            SignalsGameView(viewModel: SignalsGameViewModel(level: levelId))
        case .archive:
            ArchiveGameView(viewModel: ArchiveGameViewModel(level: levelId))
        case .cargo:
            CargoGameView(viewModel: CargoGameViewModel(level: levelId))
        case .shift:
            if let puzzle = ShiftPuzzleLoader.loadLevel(levelId) {
                // Check for a saved in-progress game state
                if let savedResult = gameResult(for: levelId),
                   let json = savedResult.shiftStateJSON,
                   let state = ShiftStateSerializer.deserialize(json),
                   let restoredGrid = state.toShiftGrid() {
                    ShiftGameView(puzzle: puzzle, restoredGrid: restoredGrid, isDaily: false, levelId: levelId)
                } else {
                    ShiftGameView(puzzle: puzzle, isDaily: false, levelId: levelId)
                }
            } else {
                Text("Failed to load level \(levelId)")
                    .foregroundStyle(.primary)
            }
        default:
            Text("Coming Soon")
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Subviews

struct LevelSelectorHeader: View {
    let iconForGame: String
    let colorForGame: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconForGame)
                .font(.system(size: 42))
                .foregroundStyle(colorForGame)
            
            Text("LOCAL PUZZLES")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.4))
                .kerning(2)
        }
        .padding(.bottom, 4)
    }
}

struct LevelSelectorStatsBar: View {
    let playedCount: Int
    let wonCount: Int
    let colorForGame: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(playedCount)/100 played · \(wonCount) won")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.5))
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForGame)
                        .frame(width: geo.size.width * CGFloat(playedCount) / 100.0, height: 6)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: playedCount)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 60)
        }
    }
}

struct LevelSelectorUnplayedCell: View {
    let levelId: Int
    
    var body: some View {
        VStack(spacing: 12) {
            Text("\(levelId)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text("NEW")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.2)))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct LevelSelectorPlayedCell: View {
    let levelId: Int
    let won: Bool
    let score: Int
    let guessesUsed: Int
    let durationSeconds: Double
    let colorForGame: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(levelId)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(won ? .white : .primary.opacity(0.35))
            
            if won {
                // Star rating for all games based on score
                let stars = starRating(score: score, guesses: guessesUsed)
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < stars ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundStyle(i < stars ? colorForGame : .primary.opacity(0.2))
                    }
                }
                // Solve time
                if durationSeconds > 0 {
                    Text(formatTime(durationSeconds))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.4))
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("LOST")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(AppTheme.error.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(won ? Color.primary.opacity(0.12) : Color.primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(won ? colorForGame.opacity(0.3) : AppTheme.error.opacity(0.15), lineWidth: 1)
        )
    }
    
    /// Returns 1–3 stars based on score tier (unified across all games)
    private func starRating(score: Int, guesses: Int) -> Int {
        if score >= 700 { return 3 }
        if score >= 400 { return 2 }
        return 1
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return mins > 0
            ? "\(mins):\(secs.formatted(.number.precision(.integerLength(2))))"
            : "\(secs)s"
    }
}

#Preview {
    NavigationStack {
        LevelSelectorView(game: .signals)
    }
    .modelContainer(for: LevelProgress.self, inMemory: true)
}
