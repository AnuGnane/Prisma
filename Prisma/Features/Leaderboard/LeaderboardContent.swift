//
//  LeaderboardContent.swift
//  Prisma
//
//  The leaderboard browser body — extracted from LeaderboardView so it can be
//  embedded inside LeaderboardTabView's segmented layout without stacking
//  NavigationStacks.
//
//  Phase 2 (2026-04-25) stripped the Metric picker and the LeaderboardMetric
//  enum — only `daily.best` IDs are configured in ASC, so surfacing a "Streak"
//  choice would point at boards that silently no-op.
//
//  Phase 3 (2026-04-25) replaced the text-chip game picker with a compact icon
//  row (matching the FriendRow pattern) and removed the Today/All-Time/Friends
//  scope picker entirely. Rankings always show today's friends-only board —
//  the only combination that makes sense for a daily-puzzle game. The
//  `LeaderboardScope` enum and the old `GamePickerChip` were removed alongside.
//

import SwiftUI
import GameKit

// MARK: - LeaderboardContent

struct LeaderboardContent: View {
    @State private var selectedGame: GameType = .signals
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var localPlayerRank: Int?
    /// Local player's own entry, queried explicitly so it's available even
    /// when `.friendsOnly` scope returns nothing (a known GC quirk on some
    /// accounts where teamPlayerID/gamePlayerID don't match across queries).
    @State private var localPlayerScore: Int?

    private let gc = GameCenterManager.shared

    private static let games: [GameType] = [.signals, .archive, .cargo, .shift, .circuit]

    var body: some View {
        Group {
            if !gc.isAuthenticated {
                unauthenticatedView
            } else {
                authenticatedContent
            }
        }
        .task                   { await loadEntries() }
        .task(id: selectedGame) { await loadEntries() }
    }

    // MARK: - Authenticated Content

    private var authenticatedContent: some View {
        VStack(spacing: 0) {
            // Compact icon row — five fixed chips, no horizontal scroll.
            HStack(spacing: 12) {
                ForEach(Self.games, id: \.self) { game in
                    GameIconChip(game: game, isSelected: selectedGame == game) {
                        selectedGame = game
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Selected game name as a section heading.
            HStack(alignment: .firstTextBaseline) {
                Text(selectedGame.displayName)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Text("· today's friends")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 2)

            // Metric clarification — tells the user what the score means.
            HStack {
                Image(systemName: metricIcon(for: selectedGame))
                    .font(.caption2.weight(.semibold))
                Text(metricSubtitle(for: selectedGame))
                    .font(.caption.weight(.medium))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if let errorMessage {
                AppEmptyState(
                    systemImage: "wifi.exclamationmark",
                    title: "Couldn't load scores",
                    message: errorMessage,
                    style: .error,
                    actionTitle: "Retry",
                    action: { Task { await loadEntries() } }
                )
            } else if entries.isEmpty {
                AppEmptyState(
                    systemImage: "trophy",
                    title: "No scores yet",
                    message: "None of your friends have posted today's score yet — check back later."
                )
            } else {
                List {
                    // "Your rank" section uses the explicit local-player query
                    // (localPlayerScore / localPlayerRank). Falls through if
                    // the local player has no score today — rank 0 / score 0
                    // is GC's "not played" sentinel and shouldn't be shown.
                    if let rank = localPlayerRank, rank > 0,
                       let score = localPlayerScore, score > 0 {
                        Section("Your rank") {
                            RankRow(
                                rank: rank,
                                name: gc.playerName ?? "You",
                                score: score,
                                game: selectedGame,
                                isHighlighted: true
                            )
                        }
                    }

                    Section("Top scores") {
                        ForEach(entries) { entry in
                            RankRow(
                                rank: entry.rank,
                                name: entry.playerName,
                                score: entry.score,
                                game: selectedGame,
                                isHighlighted: entry.isLocalPlayer
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Unauthenticated

    private var unauthenticatedView: some View {
        AppEmptyState(
            systemImage: "person.crop.circle.badge.exclamationmark",
            title: "Game Center Required",
            message: "Sign in to Game Center in Settings to view leaderboards and compete with friends.",
            actionTitle: "Open Settings",
            action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        )
    }

    // MARK: - Data Loading

    private func loadEntries() async {
        guard gc.isAuthenticated else { return }
        isLoading = true
        errorMessage = nil

        do {
            let leaderboardID = leaderboardID(for: selectedGame)
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
            guard let board = leaderboards.first else {
                #if DEBUG
                print("[LeaderboardContent] No board returned for \(selectedGame.rawValue) (ID: \(leaderboardID))")
                #endif
                entries = []
                localPlayerRank = nil
                localPlayerScore = nil
                isLoading = false
                return
            }

            // Run two queries in parallel:
            //  - .friendsOnly scope (friend ranks, includes local player on
            //    well-behaved GC accounts but is known-flaky on some)
            //  - explicit query for the local player so their entry is
            //    guaranteed regardless of scope quirks
            async let friendsResult = board.loadEntries(
                for: .friendsOnly,
                timeScope: .today,
                range: NSRange(1...20)
            )
            async let localResult = board.loadEntries(
                for: [GKLocalPlayer.local],
                timeScope: .today
            )

            let (friendsLocalEntry, friendsTopEntries, _) = try await friendsResult
            let (_, localPlayerEntries) = try await localResult

            // Prefer the explicit local-player entry; fall back to the
            // friendsOnly localEntry if the explicit query returned nothing.
            let resolvedLocalEntry = localPlayerEntries.first ?? friendsLocalEntry

            entries = friendsTopEntries.map { LeaderboardEntry(entry: $0) }
            localPlayerRank = resolvedLocalEntry.map { Int($0.rank) }
            localPlayerScore = resolvedLocalEntry.map { $0.score }

            #if DEBUG
            print("[LeaderboardContent] \(selectedGame.rawValue): friendsOnly=\(friendsTopEntries.count) local=\(localPlayerEntries.count) rank=\(localPlayerRank ?? -1) score=\(localPlayerScore ?? -1)")
            #endif
        } catch {
            #if DEBUG
            print("[LeaderboardContent] loadEntries failed: \(error.localizedDescription)")
            #endif
            errorMessage = "Check your connection and try again."
        }

        isLoading = false
    }

    /// Returns the daily-best leaderboard ID for the selected game.
    /// Streak boards are intentionally not surfaced here — see locked decision in
    /// LEADERBOARD_RESTRUCTURE_PLAN.md §2.
    private func leaderboardID(for game: GameType) -> String {
        switch game {
        case .signals: return GameCenterManager.Leaderboard.signalsDailyBest
        case .archive: return GameCenterManager.Leaderboard.archiveDailyBest
        case .cargo:   return GameCenterManager.Leaderboard.cargoDailyBest
        case .shift:   return GameCenterManager.Leaderboard.shiftDailyBest
        case .circuit: return GameCenterManager.Leaderboard.circuitDailyBest
        }
    }

    /// Human-readable subtitle explaining what the score means for each game.
    private func metricSubtitle(for game: GameType) -> String {
        switch game {
        case .signals, .archive: return "Fewest guesses wins"
        case .shift, .cargo, .circuit: return "Fastest time wins"
        }
    }

    /// Small icon for the metric subtitle.
    private func metricIcon(for game: GameType) -> String {
        switch game {
        case .signals, .archive: return "number.circle"
        case .shift, .cargo, .circuit: return "clock"
        }
    }
}

// MARK: - Supporting Types

/// Represents a single leaderboard row.
struct LeaderboardEntry: Identifiable {
    let id: UUID = UUID()
    let rank: Int
    let playerName: String
    let score: Int
    let isLocalPlayer: Bool

    init(entry: GKLeaderboard.Entry) {
        self.rank = Int(entry.rank)
        self.playerName = entry.player.displayName
        self.score = entry.score
        self.isLocalPlayer = entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
    }
}

// MARK: - Subviews

/// Compact game-picker chip used in the leaderboard top row. Icon-only,
/// 44×44 tap target. Selected state fills the circle with the game's
/// theme accent and inverts the glyph.
private struct GameIconChip: View {
    let game: GameType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let accent = AppTheme.accent(for: game)
        Button(action: action) {
            Image(systemName: game.iconName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? .white : accent)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? accent : accent.opacity(0.12))
                )
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.clear : accent.opacity(0.20), lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isSelected)
        .accessibilityLabel(Text(game.displayName))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct RankRow: View {
    let rank: Int
    let name: String
    let score: Int
    let game: GameType
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Text("\(rank)")
                    .font(.callout.weight(.heavy).monospaced())
                    .foregroundStyle(rankColor)
            }

            Text(name)
                .font(.body.weight(isHighlighted ? .semibold : .regular))
                .foregroundStyle(isHighlighted ? .primary : .secondary)

            Spacer()

            Text(formattedScore)
                .font(.callout.weight(.bold).monospaced())
                .foregroundStyle(isHighlighted ? .primary : .secondary)
        }
        .listRowBackground(isHighlighted ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    /// Formats the raw GC score with appropriate units.
    /// Guess-based games show "3 guesses", time-based games show "1:23" or "42s".
    private var formattedScore: String {
        switch game {
        case .signals, .archive:
            return "\(score) \(score == 1 ? "guess" : "guesses")"
        case .shift, .cargo, .circuit:
            return GameResult.formatElapsedSeconds(score)
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.7)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LeaderboardContent()
            .navigationTitle("Rankings")
    }
}
