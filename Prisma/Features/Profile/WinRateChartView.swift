//
//  WinRateChartView.swift
//  Prisma
//
//  Weekly win rate trend chart per game using SwiftUI Charts.
//  Defaults to last 4 weeks of data.
//

import SwiftUI
import SwiftData
import Charts

struct WinRateChartView: View {
    @Query(sort: \GameResult.date, order: .forward) private var allResults: [GameResult]
    
    @State private var timeWindow: TimeWindow = .fourWeeks
    
    private let gameColors: [GameType: Color] = [
        .signals: AppTheme.signals,
        .archive: AppTheme.archive,
        .cargo:   AppTheme.cargo,
        .shift:   AppTheme.shift
    ]
    
    enum TimeWindow: String, CaseIterable {
        case fourWeeks = "4W"
        case threeMonths = "3M"
        case allTime = "All"
        
        var days: Int? {
            switch self {
            case .fourWeeks:   return 28
            case .threeMonths: return 90
            case .allTime:     return nil
            }
        }
    }
    
    @State private var chartData: [ChartDataPoint] = []
    private struct BasicResult: Sendable {
        let date: Date
        let score: Int
        let gameTypeRaw: String
    }
    
    private func updateChartData() {
        let snapshot = allResults.map { BasicResult(date: $0.date, score: $0.score, gameTypeRaw: $0.gameTypeRaw) }
        let currentDays = timeWindow.days
        
        Task.detached(priority: .userInitiated) {
            let calendar = Calendar.current
            let games: [GameType] = [.signals, .archive, .cargo, .shift]
            var points: [ChartDataPoint] = []
            
            // Perform filtering off main thread
            var currentFiltered: [BasicResult] = []
            if let days = currentDays {
                if let cutoff = calendar.date(byAdding: .day, value: -days, to: .now) {
                    currentFiltered = snapshot.filter { $0.date >= cutoff }
                } else {
                    currentFiltered = snapshot
                }
            } else {
                currentFiltered = snapshot
            }
            
            for game in games {
                let gameResults = currentFiltered.filter { $0.gameTypeRaw == game.rawValue }
                
                let grouped = Dictionary(grouping: gameResults) { result -> Date in
                    let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: result.date)
                    return calendar.date(from: comps)!
                }
                
                for (weekStart, results) in grouped {
                    let wins = results.filter { $0.score > 0 }.count
                    let total = results.count
                    let rate = total > 0 ? Double(wins) / Double(total) * 100 : 0
                    points.append(ChartDataPoint(game: game, weekStart: weekStart, winRate: rate))
                }
            }
            
            let sortedPoints = points.sorted { $0.weekStart < $1.weekStart }
            
            await MainActor.run {
                self.chartData = sortedPoints
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WIN RATE")
                    .font(.caption2.weight(.heavy).monospaced())
                    .foregroundStyle(.secondary)
                    .kerning(1.5)
                
                Spacer()
                
                Picker("Window", selection: $timeWindow) {
                    ForEach(TimeWindow.allCases, id: \.self) { window in
                        Text(window.rawValue).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            
            if chartData.isEmpty {
                emptyState
            } else {
                chart
                legend
            }
        }
        .task(id: allResults) {
            updateChartData()
        }
        .task(id: timeWindow) {
            updateChartData()
        }
    }
    
    private var chart: some View {
        Chart(chartData) { point in
            LineMark(
                x: .value("Week", point.weekStart, unit: .weekOfYear),
                y: .value("Win Rate", point.winRate)
            )
            .foregroundStyle(by: .value("Game", point.game.displayName))
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            PointMark(
                x: .value("Week", point.weekStart, unit: .weekOfYear),
                y: .value("Win Rate", point.winRate)
            )
            .foregroundStyle(by: .value("Game", point.game.displayName))
            .symbolSize(20)
        }
        .chartForegroundStyleScale([
            GameType.signals.displayName: gameColors[.signals]!,
            GameType.archive.displayName: gameColors[.archive]!,
            GameType.cargo.displayName:   gameColors[.cargo]!,
            GameType.shift.displayName:   gameColors[.shift]!
        ])
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.1))
                AxisValueLabel {
                    Text("\(value.as(Int.self) ?? 0)%")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.primary.opacity(0.4))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.05))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(.primary.opacity(0.4))
                    .font(.caption2.monospaced())
            }
        }
        .chartLegend(.hidden)
        .frame(height: 180)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
    }
    
    private var legend: some View {
        HStack(spacing: 16) {
            ForEach([GameType.signals, .archive, .cargo, .shift], id: \.self) { game in
                HStack(spacing: 4) {
                    Circle()
                        .fill(gameColors[game]!)
                        .frame(width: 6, height: 6)
                    Text(game.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Play some games to see your win rate trend")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
    }
}

private struct ChartDataPoint: Identifiable {
    let game: GameType
    let weekStart: Date
    let winRate: Double
    
    var id: String { "\(game.rawValue)-\(weekStart.timeIntervalSince1970)" }
}

#Preview {
    WinRateChartView()
        .padding()
        .background(AppTheme.backgroundSecondary)
        .modelContainer(for: GameResult.self, inMemory: true)
}
