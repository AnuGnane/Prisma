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

    @State private var displayedMonth = Calendar.current.component(.month, from: .now)
    @State private var displayedYear = Calendar.current.component(.year, from: .now)

    private let calendar = Calendar.current
    private let daySymbols = ["M", "T", "W", "T", "F", "S", "S"]
    private let gameColors: [GameType: Color] = [
        .signals: Color(red: 0.24, green: 0.65, blue: 0.36),
        .archive: Color(red: 0.24, green: 0.52, blue: 0.85),
        .cargo:   Color(red: 1.00, green: 0.55, blue: 0.26),
        .shift:   Color(red: 0.65, green: 0.24, blue: 0.85)
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
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(6)
                }

                Spacer()
                Text(monthTitle.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .kerning(1.5)
                Spacer()

                Button {
                    stepMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(6)
                }
            }

            // Day headers
            HStack(spacing: 0) {
                ForEach(daySymbols, id: \.self) { d in
                    Text(d)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
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
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 36)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
    }

    // MARK: - Cell

    private func calendarCell(day: Int) -> some View {
        let date = calendar.date(from: DateComponents(year: displayedYear, month: displayedMonth, day: day))!
        let dayResults = dailyResults(for: date)
        let isToday = calendar.isDateInToday(date)

        return VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 12, weight: isToday ? .bold : .medium, design: .monospaced))
                .foregroundStyle(isToday ? .white : .white.opacity(0.5))

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
            isToday
                ? RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08))
                : RoundedRectangle(cornerRadius: 8).fill(Color.clear)
        )
    }

    // MARK: - Helpers

    private func dailyResults(for date: Date) -> [GameResult] {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return allResults.filter { $0.isDaily && $0.date >= start && $0.date < end }
    }

    private func dotColor(for result: GameResult) -> Color {
        let type = GameType(rawValue: result.gameTypeRaw) ?? .signals
        let base = gameColors[type] ?? .white
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
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .modelContainer(for: GameResult.self, inMemory: true)
}
