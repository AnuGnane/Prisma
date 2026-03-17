//
//  SolveTimeStatsView.swift
//  Prisma
//
//  Displays per-game average and best solve times using SwiftUI Charts.
//

import SwiftUI
import SwiftData
import Charts

struct SolveTimeStatsView: View {
    @Query private var allResults: [GameResult]
    
    private let games: [GameType] = [.signals, .archive, .cargo, .shift]
    private let gameColors: [GameType: Color] = [
        .signals: AppTheme.signals,
        .archive: AppTheme.archive,
        .cargo:   AppTheme.cargo,
        .shift:   AppTheme.shift
    ]
    
    private func stats(for game: GameType) -> (avg: Double, best: Double, total: Int) {
        let results = allResults.filter { $0.gameTypeRaw == game.rawValue && $0.durationSeconds > 0 && $0.score > 0 }
        guard !results.isEmpty else { return (0, 0, 0) }
        let times = results.map(\.durationSeconds)
        let avg = times.reduce(0, +) / Double(times.count)
        let best = times.min() ?? 0
        return (avg, best, results.count)
    }
    
    private var hasData: Bool {
        games.contains { stats(for: $0).total > 0 }
    }
    
    private var barData: [TimeBarData] {
        games.compactMap { game in
            let s = stats(for: game)
            guard s.total > 0 else { return nil }
            return TimeBarData(game: game, avgTime: s.avg)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SOLVE TIMES")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)
                .kerning(1.5)
            
            if !hasData {
                emptyState
            } else {
                chart
                statsCards
            }
        }
    }
    
    private var chart: some View {
        Chart(barData) { item in
            BarMark(
                x: .value("Game", item.game.displayName),
                y: .value("Avg Time", item.avgTime)
            )
            .foregroundStyle(gameColors[item.game] ?? .primary)
            .cornerRadius(6)
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.1))
                AxisValueLabel {
                    Text(formatTime(value.as(Double.self) ?? 0))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.4))
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .foregroundStyle(.primary.opacity(0.5))
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .frame(height: 140)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
    }
    
    private var statsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(games, id: \.self) { game in
                let s = stats(for: game)
                if s.total > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(gameColors[game]!)
                                .frame(width: 6, height: 6)
                            Text(game.displayName)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.primary.opacity(0.8))
                        }
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(formatTime(s.avg))
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(gameColors[game]!)
                                Text("avg")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.3))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(formatTime(s.best))
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.6))
                                Text("best")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.3))
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "stopwatch")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Win some games to track your solve times")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return mins > 0 ? String(format: "%d:%02d", mins, secs) : "\(secs)s"
    }
}

private struct TimeBarData: Identifiable {
    let game: GameType
    let avgTime: Double
    var id: String { game.rawValue }
}

#Preview {
    SolveTimeStatsView()
        .padding()
        .background(AppTheme.backgroundSecondary)
        .modelContainer(for: GameResult.self, inMemory: true)
}
