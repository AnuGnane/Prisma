//
//  FriendRow.swift
//  Prisma
//
//  A single row in the Friends tab list. Shows:
//    • GK avatar (loaded asynchronously, cached in-memory)
//    • Display name
//    • "X/5 solved" pill (tinted green when > 0)
//    • Five mini game-icon dots coloured by whether they solved that game today
//

import SwiftUI
import GameKit

struct FriendRow: View {
    let friend: GKPlayer
    let summary: FriendTodaySummary?

    var body: some View {
        HStack(spacing: 14) {
            // ── Avatar ───────────────────────────────────────────────────────
            FriendAvatarView(player: friend, size: 42)

            // ── Name + game dots ─────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                Text(friend.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    ForEach([GameType.signals, .archive, .cargo, .shift, .circuit], id: \.self) { game in
                        gameIcon(game: game)
                    }
                }
            }

            Spacer()

            // ── Solved-today pill ────────────────────────────────────────────
            solvedPill
        }
        .padding(.vertical, 4)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func gameIcon(game: GameType) -> some View {
        let solved = summary?.perGame[game]?.score != nil
        Image(systemName: game.iconName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(solved ? AppTheme.accent(for: game) : Color.primary.opacity(0.20))
            .frame(width: 18, height: 18)
    }

    private var solvedPill: some View {
        let count = summary?.gamesSolvedToday ?? 0
        let hasSolved = count > 0
        return Text("\(count)/5")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(hasSolved ? .white : Color.primary.opacity(0.45))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(hasSolved ? Color.green.opacity(0.75) : Color.primary.opacity(0.08))
            )
    }
}

// MARK: - FriendAvatarView

/// Loads and caches `GKPlayer` photos using a process-lifetime in-memory cache.
struct FriendAvatarView: View {
    let player: GKPlayer
    let size: CGFloat

    // Shared cache avoids re-fetching when the list is scrolled
    private static var cache: [String: Image] = [:]

    @State private var image: Image?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: size, height: size)

            if let image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.7, height: size * 0.7)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: player.gamePlayerID) {
            await loadPhoto()
        }
    }

    @MainActor
    private func loadPhoto() async {
        let pid = player.gamePlayerID
        if let cached = Self.cache[pid] {
            image = cached
            return
        }
        do {
            let uiImage = try await player.loadPhoto(for: .small)
            let img = Image(uiImage: uiImage)
            Self.cache[pid] = img
            image = img
        } catch {
            #if DEBUG
            print("[FriendRow] loadPhoto failed for \(pid): \(error.localizedDescription)")
            #endif
        }
    }
}
