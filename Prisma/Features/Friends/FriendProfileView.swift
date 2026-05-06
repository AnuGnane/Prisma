//
//  FriendProfileView.swift
//  Prisma
//
//  Per-friend detail screen. Shows:
//    • Header: avatar, display name
//    • Per-game stats grid (best score, head-to-head)
//    • Aggregate head-to-head strip (wins / losses across all games)
//
//  Phase 2 (2026-04-25) removed the challenge button (deep-link URL had no
//  handler) and the per-game streak flame badge (streak boards stay unused
//  in ASC, so the value is always 0).
//

import SwiftUI
import GameKit

struct FriendProfileView: View {
    let friend: GKPlayer

    @State private var profileStats: [GameType: FriendGameStats] = [:]
    @State private var localStats:   [GameType: FriendGameStats] = [:]
    @State private var isLoading = true
    @State private var loadError: String?

    private let service = FriendsService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground()

                if isLoading {
                    ProgressView("Loading stats…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = loadError {
                    AppEmptyState(
                        systemImage: "wifi.exclamationmark",
                        title: "Couldn't load stats",
                        message: error,
                        style: .error,
                        actionTitle: "Retry",
                        action: { Task { await loadProfile() } }
                    )
                } else {
                    profileContent
                }
            }
            .navigationTitle(friend.displayName)
            .navigationBarTitleDisplayMode(.large)
            .task { await loadProfile() }
        }
    }

    // MARK: - Profile Content

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ── Header ───────────────────────────────────────────────────
                profileHeader

                // ── Head-to-head aggregate ───────────────────────────────────
                headToHeadBanner

                // ── Per-game stat cards ──────────────────────────────────────
                VStack(spacing: 12) {
                    ForEach([GameType.signals, .archive, .cargo, .shift, .circuit], id: \.self) { game in
                        if let stats = profileStats[game] {
                            GameStatCard(game: game, stats: stats, myStats: myStats(for: game))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            FriendAvatarView(player: friend, size: 80)
            Text(friend.displayName)
                .font(.system(.title2, design: .rounded, weight: .bold))
        }
        .padding(.top, 8)
    }

    // MARK: - Head-to-Head Banner

    private var headToHeadBanner: some View {
        let outcomes = GameType.allCases.compactMap { game -> HeadToHead.Outcome? in
            guard let mine = myStats(for: game), let theirs = profileStats[game] else { return nil }
            return HeadToHead(game: game, myStats: mine, theirStats: theirs).outcome
        }
        let wins   = outcomes.filter { $0 == .iWin }.count
        let losses = outcomes.filter { $0 == .theyWin }.count
        let ties   = outcomes.filter { $0 == .tie }.count

        return HStack(spacing: 0) {
            headToHeadStat(value: "\(wins)",   label: "You",   color: .green)
            Divider().frame(height: 36)
            headToHeadStat(value: "\(ties)",   label: "Tied",  color: .secondary)
            Divider().frame(height: 36)
            headToHeadStat(value: "\(losses)", label: "Them",  color: AppTheme.error)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.cellFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(AppTheme.cellBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 20)
    }

    private func headToHeadStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(color)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        isLoading = true
        loadError = nil
        do {
            // Load friend's stats and local player's stats concurrently — one round
            // trip each, both needed before the H2H banner can show a result.
            async let friendLoad = service.loadFriendProfile(for: friend)
            async let localLoad  = service.loadLocalPlayerStats()
            let (loaded, myLoaded) = try await (friendLoad, localLoad)
            profileStats = loaded
            localStats   = myLoaded
        } catch {
            loadError = "Check your connection and try again."
        }
        isLoading = false
    }

    /// Returns the local player's all-time stats for a game, used for H2H comparison.
    private func myStats(for game: GameType) -> FriendGameStats? {
        localStats[game]
    }
}

// MARK: - GameStatCard

private struct GameStatCard: View {
    let game: GameType
    let stats: FriendGameStats
    let myStats: FriendGameStats?

    var body: some View {
        let accent = AppTheme.accent(for: game)
        let h2h = myStats.map { HeadToHead(game: game, myStats: $0, theirStats: stats) }
        let outcome = h2h?.outcome ?? .notEnoughData

        HStack(spacing: 14) {
            // Game icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: game.iconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
            }

            // Stats
            VStack(alignment: .leading, spacing: 3) {
                Text(game.displayName)
                    .font(.subheadline.weight(.semibold))

                if let best = stats.bestAllTimeScore {
                    Label(formattedScore(best, game: game), systemImage: "trophy")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No games yet")
                        .font(.caption)
                        .foregroundStyle(AppTheme.dimText)
                }
            }

            Spacer()

            // H2H outcome badge
            outcomeChip(outcome)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.cellFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(accent.opacity(outcome == .iWin ? 0.30 : 0.10), lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func outcomeChip(_ outcome: HeadToHead.Outcome) -> some View {
        switch outcome {
        case .iWin:
            outcomeLabel("You win", color: .green)
        case .theyWin:
            outcomeLabel("They win", color: AppTheme.error)
        case .tie:
            outcomeLabel("Tied", color: .secondary)
        case .notEnoughData:
            EmptyView()
        }
    }

    private func outcomeLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    /// Formats a raw GC score with appropriate units.
    private func formattedScore(_ score: Int, game: GameType) -> String {
        switch game {
        case .signals, .archive:
            return "\(score) \(score == 1 ? "guess" : "guesses")"
        case .shift, .cargo, .circuit:
            if score >= 60 {
                let m = score / 60
                let s = score % 60
                return "\(m):\(s.formatted(.number.precision(.integerLength(2))))"
            } else {
                return "\(score)s"
            }
        }
    }
}
