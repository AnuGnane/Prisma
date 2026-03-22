//
//  DailyCalendarView.swift
//  Prisma
//
//  Monthly calendar grid showing daily game results across all games.
//  Color-coded dots per day: green = won, red = lost, empty = unplayed.
//

import SwiftUI
import SwiftData

struct DailyCalendarView: View {
    @Query(sort: \GameResult.date, order: .reverse) private var allResults: [GameResult]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var displayedMonth = Calendar.current.component(.month, from: .now)
    @State private var displayedYear = Calendar.current.component(.year, from: .now)
    @State private var selectedDay: Int?

    private let calendar = Calendar.current
    private let daySymbols = ["M", "T", "W", "T", "F", "S", "S"]
    private let gameColors: [GameType: Color] = [
        .signals: AppTheme.signals,
        .archive: AppTheme.archive,
        .cargo:   AppTheme.cargo,
        .shift:   AppTheme.shift
    ]

    private var displayDate: Date {
        calendar.date(from: DateComponents(year: displayedYear, month: displayedMonth))!
    }

    private var monthTitle: String {
        displayDate.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    stepMonth(-1)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.5))
                        .padding(6)
                }
                .accessibilityLabel("Previous month")

                Spacer()
                Text(monthTitle.uppercased())
                    .font(.caption.weight(.heavy).monospaced())
                    .foregroundStyle(.primary.opacity(0.6))
                    .kerning(1.5)
                Spacer()

                Button {
                    stepMonth(1)
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.5))
                        .padding(6)
                }
                .accessibilityLabel("Next month")
            }

            // Day headers
            HStack(spacing: 0) {
                ForEach(daySymbols.indices, id: \.self) { i in
                    Text(daySymbols[i])
                        .font(.caption2.weight(.bold).monospaced())
                        .foregroundStyle(.primary.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            let weeks = weeksInMonth()
            ForEach(weeks.indices, id: \.self) { weekIdx in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { dayIdx in
                        let day = weeks[weekIdx][dayIdx]
                        if day > 0 {
                            calendarCell(day: day)
                                .onTapGesture {
                                    let updateSelection = {
                                        selectedDay = selectedDay == day ? nil : day
                                    }
                                    if reduceMotion {
                                        updateSelection()
                                    } else {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            updateSelection()
                                        }
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(accessibilityDayLabel(day: day))
                                .accessibilityHint("Double tap to view day results")
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 36)
                        }
                    }
                }
            }
            
            // Intensity legend
            intensityLegend
            
            // Expanded day detail
            if let day = selectedDay {
                dayDetailView(day: day)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
    }

    // MARK: - Cell

    private func calendarCell(day: Int) -> some View {
        let date = calendar.date(from: DateComponents(year: displayedYear, month: displayedMonth, day: day))!
        let dayResults = dailyResults(for: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDay == day
        let intensity = intensityLevel(for: dayResults)

        return VStack(spacing: 2) {
            Text("\(day)")
                .font(.caption.weight(isToday ? .bold : .medium).monospaced())
                .foregroundStyle(isToday ? .white : .primary.opacity(0.5))

            if dayResults.isEmpty {
                Circle().fill(Color.clear).frame(width: 4, height: 4)
            } else {
                HStack(spacing: 2) {
                    ForEach(dayResults, id: \.persistentModelID) { result in
                        Circle()
                            .fill(dotColor(for: result))
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(intensityFill(level: intensity, isToday: isToday, isSelected: isSelected))
        )
        .overlay(
            isSelected
                ? RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                : nil
        )
    }
    
    // MARK: - Intensity
    
    /// 0 = no games, 1-4 based on games completed that day
    private func intensityLevel(for results: [GameResult]) -> Int {
        min(results.count, 4)
    }
    
    private func intensityFill(level: Int, isToday: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return Color.primary.opacity(0.12)
        }
        if isToday && level == 0 {
            return Color.primary.opacity(0.08)
        }
        switch level {
        case 0: return .clear
        case 1: return AppTheme.signals.opacity(0.10)
        case 2: return AppTheme.signals.opacity(0.20)
        case 3: return AppTheme.signals.opacity(0.30)
        default: return AppTheme.signals.opacity(0.40)
        }
    }
    
    // MARK: - Intensity Legend
    
    private var intensityLegend: some View {
        HStack(spacing: 6) {
            Text("Less")
                .font(.caption2.weight(.medium).monospaced())
                .foregroundStyle(.primary.opacity(0.3))
            
            ForEach(0..<5) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level == 0 ? Color.primary.opacity(0.06) : AppTheme.signals.opacity(Double(level) * 0.10))
                    .frame(width: 10, height: 10)
            }
            
            Text("More")
                .font(.caption2.weight(.medium).monospaced())
                .foregroundStyle(.primary.opacity(0.3))
        }
        .padding(.top, 4)
    }
    
    // MARK: - Day Detail
    
    private func dayDetailView(day: Int) -> some View {
        let date = calendar.date(from: DateComponents(year: displayedYear, month: displayedMonth, day: day))!
        let dayResults = dailyResults(for: date)
        
        return VStack(alignment: .leading, spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(.primary.opacity(0.7))
            
            if dayResults.isEmpty {
                Text("No games played")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.3))
            } else {
                ForEach(dayResults, id: \.persistentModelID) { result in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(dotColor(for: result))
                            .frame(width: 6, height: 6)
                        
                        Text(result.gameType.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary.opacity(0.8))
                        
                        Spacer()
                        
                        if result.score > 0 {
                            Text("Won")
                                .font(.caption2.weight(.medium).monospaced())
                                .foregroundStyle(dotColor(for: result))
                        } else {
                            Text("Lost")
                                .font(.caption2.weight(.medium).monospaced())
                                .foregroundStyle(.primary.opacity(0.3))
                        }
                        
                        if result.durationSeconds > 0 {
                            Text(formatDuration(result.durationSeconds))
                                .font(.caption2.weight(.medium).monospaced())
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06)))
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return mins > 0
            ? "\(mins):\(secs.formatted(.number.precision(.integerLength(2))))"
            : "\(secs)s"
    }

    // MARK: - Helpers

    private func dailyResults(for date: Date) -> [GameResult] {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return allResults.filter { $0.isDaily && $0.date >= start && $0.date < end }
    }

    private func dotColor(for result: GameResult) -> Color {
        let type = GameType(rawValue: result.gameTypeRaw) ?? .signals
        let base = gameColors[type] ?? .primary
        return result.score > 0 ? base : base.opacity(0.3)
    }

    private func stepMonth(_ delta: Int) {
        var comps = DateComponents(year: displayedYear, month: displayedMonth)
        comps.month! += delta
        if let newDate = calendar.date(from: comps) {
            displayedMonth = calendar.component(.month, from: newDate)
            displayedYear = calendar.component(.year, from: newDate)
        }
    }

    private func accessibilityDayLabel(day: Int) -> String {
        guard let date = calendar.date(from: DateComponents(year: displayedYear, month: displayedMonth, day: day)) else {
            return "Day \(day)"
        }
        let resultsCount = dailyResults(for: date).count
        if resultsCount == 0 {
            return "\(date.formatted(.dateTime.weekday(.wide).month(.wide).day())), no games played"
        }
        let gamesWord = resultsCount == 1 ? "game" : "games"
        return "\(date.formatted(.dateTime.weekday(.wide).month(.wide).day())), \(resultsCount) \(gamesWord) played"
    }

    private func weeksInMonth() -> [[Int]] {
        let range = calendar.range(of: .day, in: .month, for: displayDate)!
        let firstDay = calendar.component(.weekday, from: displayDate)
        // Convert Sunday=1 to Monday-based: Mon=0, Tue=1, ..., Sun=6
        let offset = (firstDay + 5) % 7

        var weeks: [[Int]] = []
        var currentWeek = Array(repeating: 0, count: 7)
        var dayIndex = offset

        for day in range {
            currentWeek[dayIndex] = day
            dayIndex += 1
            if dayIndex == 7 {
                weeks.append(currentWeek)
                currentWeek = Array(repeating: 0, count: 7)
                dayIndex = 0
            }
        }
        if dayIndex > 0 {
            weeks.append(currentWeek)
        }
        return weeks
    }
}

#Preview {
    DailyCalendarView()
        .padding()
        .background(AppTheme.backgroundSecondary)
        .modelContainer(for: GameResult.self, inMemory: true)
}
