//
//  LeaderboardView.swift
//  Prisma
//
//  Displays Game Center leaderboards per game and time scope.
//  Falls back to a "Sign in to Game Center" prompt if unauthenticated.
//

import SwiftUI
import GameKit

// MARK: - LeaderboardView

struct LeaderboardView: View {
    @State private var selectedGame: GameType = .signals
    @State private var selectedScope: LeaderboardScope = .allTime
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var localPlayerRank: Int?

    private let gc = GameCenterManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground()

                if !gc.isAuthenticated {
                    unauthenticatedView
                } else {
                    leaderboardContent
                }
            }
            .navigationTitle("Leaderboards")
            .navigationBarTitleDisplayMode(.large)
            .task(id: selectedGame) { await loadEntries() }
            .task(id: selectedScope) { await loadEntries() }
        }
    }

    // MARK: - Authenticated Content

    private var leaderboardContent: some View {
        VStack(spacing: 0) {
            // Game picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([GameType.signals, .archive, .cargo, .shift], id: \.self) { game in
                        GamePickerChip(game: game, isSelected: selectedGame == game) {
                            selectedGame = game
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            // Scope picker
            Picker("Scope", selection: $selectedScope) {
                ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                    Text(scope.displayName)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView(errorMessage, systemImage: "wifi.exclamationmark")
                    .frame(maxHeight: .infinity)
            } else if entries.isEmpty {
                ContentUnavailableView("No scores yet", systemImage: "trophy")
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    if let rank = localPlayerRank {
                        Section("Your rank") {
                            RankRow(rank: rank, name: gc.playerName ?? "You", score: entries.first(where: { $0.isLocalPlayer })?.score ?? 0, isHighlighted: true)
                        }
                    }

                    Section("Top scores") {
                        ForEach(entries) { entry in
                            RankRow(
                                rank: entry.rank,
                                name: entry.playerName,
                                score: entry.score,
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
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)

            Text("Game Center Required")
                .font(.title2.weight(.bold))

            Text("Sign in to Game Center in Settings to view leaderboards and compete with friends.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Data Loading

    private func loadEntries() async {
        guard gc.isAuthenticated else { return }
        isLoading = true
        errorMessage = nil

        do {
            let leaderboardID = leaderboardID(for: selectedGame, scope: selectedScope)
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
            guard let board = leaderboards.first else {
                entries = []
                isLoading = false
                return
            }

            let (localEntry, entries: topEntries, _) = try await board.loadEntries(
                for: .global,
                timeScope: selectedScope.gkTimeScope,
                range: NSRange(1...20)
            )

            entries = topEntries.map { LeaderboardEntry(entry: $0) }
            localPlayerRank = localEntry.map { Int($0.rank) }
        } catch {
            errorMessage = "Couldn't load scores. Check your connection."
        }

        isLoading = false
    }

    private func leaderboardID(for game: GameType, scope: LeaderboardScope) -> String {
        switch (game, scope) {
        case (.signals, .today):   return GameCenterManager.Leaderboard.signalsDailyBest
        case (.signals, _):        return GameCenterManager.Leaderboard.signalsDailyBest
        case (.archive, .today):   return GameCenterManager.Leaderboard.archiveDailyBest
        case (.archive, _):        return GameCenterManager.Leaderboard.archiveDailyBest
        default:                   return GameCenterManager.Leaderboard.localMastery
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

enum LeaderboardScope: String, CaseIterable {
    case today = "today"
    case allTime = "allTime"
    case friends = "friends"

    var displayName: String {
        switch self {
        case .today:   return "Today"
        case .allTime: return "All Time"
        case .friends: return "Friends"
        }
    }

    var gkTimeScope: GKLeaderboard.TimeScope {
        switch self {
        case .today:   return .today
        case .allTime: return .allTime
        case .friends: return .allTime  // Friends filtering via playerScope
        }
    }
}

// MARK: - Subviews

private struct GamePickerChip: View {
    let game: GameType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(game.displayName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? AppTheme.accent(for: game) : Color.primary.opacity(0.08))
                )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

private struct RankRow: View {
    let rank: Int
    let name: String
    let score: Int
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

            Text(score.formatted())
                .font(.callout.weight(.bold).monospaced())
                .foregroundStyle(isHighlighted ? .primary : .secondary)
        }
        .listRowBackground(isHighlighted ? Color.accentColor.opacity(0.08) : Color.clear)
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
    LeaderboardView()
}
