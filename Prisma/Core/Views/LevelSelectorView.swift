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
    @Query private var progressList: [LevelProgress]
    
    init(game: GameType) {
        self.game = game
        let raw = game.rawValue
        _progressList = Query(filter: #Predicate<LevelProgress> { $0.gameTypeRaw == raw })
    }
    
    // MARK: - Aggregate Stats
    
    private var playedCount: Int { progressList.filter(\.isPlayed).count }
    private var wonCount: Int { progressList.filter(\.won).count }
    
    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.10)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    header
                    statsBar
                    levelGrid
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(game.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.10), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: iconForGame)
                .font(.system(size: 42))
                .foregroundStyle(colorForGame)
            
            Text("LOCAL PUZZLES")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .kerning(2)
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        VStack(spacing: 8) {
            Text("\(playedCount)/100 played · \(wonCount) won")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForGame)
                        .frame(width: geo.size.width * CGFloat(playedCount) / 100.0, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: playedCount)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 60)
        }
    }
    
    // MARK: - Grid
    
    private var levelGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(1...100, id: \.self) { levelId in
                let progress = progressList.first(where: { $0.levelId == levelId })
                let isPlayed = progress?.isPlayed ?? false
                
                if isPlayed {
                    playedCell(levelId: levelId, won: progress?.won ?? false, score: progress?.score ?? 0)
                } else {
                    NavigationLink(destination: destination(for: levelId)) {
                        unplayedCell(levelId: levelId)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Cells
    
    @ViewBuilder
    private func unplayedCell(levelId: Int) -> some View {
        VStack(spacing: 12) {
            Text("\(levelId)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text("NEW")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.2)))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func playedCell(levelId: Int, won: Bool, score: Int) -> some View {
        VStack(spacing: 12) {
            Text("\(levelId)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(won ? .white : .white.opacity(0.35))
            
            if won {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("\(score)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(colorForGame)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("LOST")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color(red: 0.85, green: 0.30, blue: 0.30).opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(won ? Color(white: 0.12) : Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(won ? colorForGame.opacity(0.3) : Color(red: 0.85, green: 0.30, blue: 0.30).opacity(0.15), lineWidth: 1)
        )
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
        case .signals: return Color(red: 0.24, green: 0.65, blue: 0.36)
        case .archive: return Color(red: 0.24, green: 0.52, blue: 0.85)
        case .cargo:   return Color(red: 0.85, green: 0.52, blue: 0.24)
        case .shift:   return Color(red: 0.65, green: 0.24, blue: 0.85)
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
        default:
            Text("Coming Soon")
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    NavigationStack {
        LevelSelectorView(game: .signals)
    }
    .modelContainer(for: LevelProgress.self, inMemory: true)
}
