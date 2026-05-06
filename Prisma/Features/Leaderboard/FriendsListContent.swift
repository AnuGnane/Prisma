//
//  FriendsListContent.swift
//  Prisma
//
//  The friends-list body — extracted from FriendsTabView so it can be embedded
//  inside LeaderboardTabView's segmented layout without stacking NavigationStacks.
//  Owns the friend-sheet presentation (tapping a row opens FriendProfileView).
//
//  Behaviorally identical to the old FriendsTabView body; the auth state machine,
//  skeleton list, empty state, pull-to-refresh, and scene-phase refresh are all
//  preserved verbatim.
//

import SwiftUI
import GameKit

struct FriendsListContent: View {
    @State private var service = FriendsService.shared
    @State private var selectedFriend: GKPlayer?
    @Environment(\.scenePhase) private var scenePhase

    private let gc = GameCenterManager.shared

    /// Tracks whether a cross-day boundary was detected so we force a full
    /// refetch instead of hitting the 30 s summary cache.
    @State private var lastSeenDay: Int = Calendar.current.component(.day, from: .now)

    var body: some View {
        content
            .sheet(item: $selectedFriend) { friend in
                FriendProfileView(friend: friend)
            }
            // Use onAppear (not .task) so this fires every time the user switches
            // back to the Friends segment, not just on first load. Combined with
            // the 30 s cache in FriendsService, this refreshes scores without
            // spamming GK.
            .onAppear { Task { await onAppear() } }
            // Auto-refresh when returning from background so friend scores update
            // without manual pull-to-refresh.
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await service.loadTodaySummaries(force: true) }
                }
            }
            // "+" button → opens the Game Center dashboard so the user can
            // search, send, and accept friend requests. Apple owns the
            // friend-management flow; we can only deep-link into their UI.
            // Hidden until GC and friends-permission are both authorized so
            // it doesn't appear on the sign-in / permission-gate states.
            .toolbar {
                if gc.isAuthenticated && service.authState == .authorized {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            GKAccessPoint.shared.trigger(handler: {})
                        } label: {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.body.weight(.semibold))
                        }
                        .accessibilityLabel(Text("Add Friends"))
                    }
                }
            }
    }

    // MARK: - Content Router

    @ViewBuilder
    private var content: some View {
        if !gc.isAuthenticated {
            // GC not signed in
            FriendsAuthGateView(state: .unknown) {
                openSettings()
            }
        } else {
            switch service.authState {
            case .unknown:
                // Still determining — show spinner
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .notDetermined:
                FriendsAuthGateView(state: .notDetermined) {
                    Task { await service.loadFriends() }
                }

            case .denied, .restricted:
                FriendsAuthGateView(state: service.authState) {
                    openSettings()
                }

            case .authorized:
                authorizedContent
            }
        }
    }

    // MARK: - Authorized Content

    @ViewBuilder
    private var authorizedContent: some View {
        if service.isLoadingFriends && service.friends.isEmpty {
            friendsSkeletonList
        } else if let error = service.friendsError, service.friends.isEmpty {
            loadErrorState(message: error)
        } else if service.friends.isEmpty {
            noFriendsEmptyState
        } else {
            friendsList
        }
    }

    // ── Load-error state ──────────────────────────────────────────────────────

    private func loadErrorState(message: String) -> some View {
        AppEmptyState(
            systemImage: "wifi.exclamationmark",
            title: "Couldn't load friends",
            message: message,
            style: .error,
            actionTitle: "Retry",
            action: { Task { await service.loadFriends() } }
        )
    }

    // ── Friends list ──────────────────────────────────────────────────────────

    private var friendsList: some View {
        List {
            // My own today-summary header
            Section {
                myStatusRow
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Friends
            Section {
                ForEach(service.sortedFriends, id: \.gamePlayerID) { friend in
                    Button {
                        selectedFriend = friend
                    } label: {
                        FriendRow(
                            friend: friend,
                            summary: service.summaries[friend.gamePlayerID]
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("FRIENDS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable {
            await service.loadFriends()
        }
        .overlay(alignment: .bottom) {
            if service.isLoadingSummaries {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Updating scores…")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 12)
            }
        }
    }

    // ── My status row ─────────────────────────────────────────────────────────

    private var myStatusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(gc.playerName ?? "You")
                    .font(.subheadline.weight(.semibold))
                Text("\(service.friends.count) friend\(service.friends.count == 1 ? "" : "s") • pull to refresh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // ── Empty states ──────────────────────────────────────────────────────────

    private var noFriendsEmptyState: some View {
        AppEmptyState(
            systemImage: "person.2.slash",
            title: "No friends yet",
            message: "Add friends in Game Center to see their daily results and head-to-head stats.",
            actionTitle: "Open Game Center",
            action: { GKAccessPoint.shared.trigger(handler: {}) }
        )
    }

    // ── Loading skeleton ──────────────────────────────────────────────────────

    private var friendsSkeletonList: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 120, height: 13)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 80, height: 10)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .allowsHitTesting(false)
        .redacted(reason: .placeholder)
    }

    // MARK: - Lifecycle

    private func onAppear() async {
        guard gc.isAuthenticated else { return }

        // Detect calendar-day boundary — if we crossed midnight since the last
        // view appearance, invalidate the summary cache so `.today` scores
        // reflect the new day immediately.
        let currentDay = Calendar.current.component(.day, from: .now)
        let crossedDay = currentDay != lastSeenDay
        if crossedDay { lastSeenDay = currentDay }

        // First visit: check status, then auto-load if already authorized
        if service.authState == .unknown {
            await service.checkAuthorizationStatus()
        }

        if service.authState == .authorized && service.friends.isEmpty {
            await service.loadFriends()
        } else if service.authState == .authorized && !service.friends.isEmpty {
            // Already have friends — refresh summaries.
            // Force if we crossed a day boundary so today's scores reset.
            await service.loadTodaySummaries(force: crossedDay)
        }
    }

    // MARK: - Helpers

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - GKPlayer: Identifiable (for sheet(item:))
//
// Declared here so the new Features/Leaderboard group owns it. The old
// FriendsTabView wrapper drops its own copy to avoid a duplicate conformance.

extension GKPlayer: @retroactive Identifiable {
    public var id: String { gamePlayerID }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FriendsListContent()
            .navigationTitle("Friends")
    }
}
