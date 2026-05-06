//
//  GamesHomeView.swift
//  Prisma
//
//  Home feed showing all available games as hero cards.
//

import SwiftUI
import SwiftData

// MARK: - Game Detail Destination

struct GameDetailDestination: Hashable {
    let game: GameType
}

// MARK: - Games Home (Unified Feed)

struct GamesHomeView: View {
    @Environment(\.modelContext) private var modelContext

    // MARK: - Daily Sweep detection

    /// Today's daily results, refreshed automatically by SwiftData.
    @Query private var todayResults: [GameResult]

    /// Persisted flag: timestamp of the last day we showed the sweep.
    /// Prevents re-showing after the user dismisses it today.
    @AppStorage("sweep.lastShownDay") private var lastSweepShownDay: String = ""

    @State private var showSweep = false

    init() {
        // Filter to today's winning daily results. SwiftData @Query predicates
        // can't call Calendar helpers directly, so we filter by `isDaily` here
        // and winnow to today in the view — the full-day predicate would require
        // a stored "startOfDay" date which isn't available at init time.
        _todayResults = Query(
            filter: #Predicate<GameResult> { $0.isDaily && $0.score > 0 },
            sort: \.date, order: .forward
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection

                        VStack(spacing: 16) {
                            ForEach([GameType.signals, .archive, .cargo, .shift, .circuit], id: \.self) { game in
                                GameHeroCard(game: game)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Footer tagline
                        Label("Life is more fun with puzzles.", systemImage: "sparkles")
                            .font(.footnote.weight(.medium))
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
            .sheet(isPresented: $showSweep) {
                DailySweepView(results: todayWins)
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: todayWins.count) { _, count in
                triggerSweepIfEligible()
            }
            .onAppear {
                triggerSweepIfEligible()
            }
        }
    }

    // MARK: - Sweep helpers

    /// Today's winning daily results, one per game type (deduped).
    private var todayWins: [GameResult] {
        let today = Calendar.current.startOfDay(for: .now)
        let wins = todayResults.filter { Calendar.current.startOfDay(for: $0.date) == today }
        // Deduplicate: keep the latest result per game type
        var seen = Set<GameType>()
        return wins.filter { seen.insert($0.gameType).inserted }
    }

    private var todayDayString: String {
        let d = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return "\(d.year!)-\(d.month!)-\(d.day!)"
    }

    private func triggerSweepIfEligible() {
        guard DailySweepView.isSweep(todayWins) else { return }
        guard lastSweepShownDay != todayDayString else { return }
        lastSweepShownDay = todayDayString
        showSweep = true
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prisma")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: AppTheme.brandGradient,
                        startPoint: .leading, endPoint: .trailing
                    )
                )

            Text(greetingText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.8))

            Text("Five games. One daily challenge each.")
                .font(.subheadline.weight(.medium))
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
