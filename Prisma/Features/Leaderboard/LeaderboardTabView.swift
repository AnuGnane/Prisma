//
//  LeaderboardTabView.swift
//  Prisma
//
//  Root view of the "Leaderboard" tab (replaces the old Friends tab).
//
//  Layout:
//    ┌─────────────────────────────────┐
//    │        Leaderboard              │  ← large nav title
//    │  ┌──────────┬──────────┐        │
//    │  │ Rankings │ Friends  │        │  ← segmented picker
//    │  └──────────┴──────────┘        │
//    │                                 │
//    │  [ selected segment's content ] │
//    └─────────────────────────────────┘
//
//  Segment selection is persisted via @SceneStorage so it survives tab
//  switches and app relaunches.
//
//  GKAccessPoint lifecycle lives here (migrated from the old FriendsTabView)
//  so the Game Center dashboard button is visible on both segments.
//

import SwiftUI
import GameKit

struct LeaderboardTabView: View {
    @SceneStorage("leaderboardSegment") private var segment: Segment = .rankings

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground()

                VStack(spacing: 0) {
                    segmentPicker
                    segmentContent
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear  { GKAccessPoint.shared.isActive = true }
        .onDisappear { GKAccessPoint.shared.isActive = false }
    }

    // MARK: - Segment Picker

    private var segmentPicker: some View {
        Picker("Segment", selection: $segment) {
            ForEach(Segment.allCases, id: \.self) { seg in
                Text(seg.title).tag(seg)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    // MARK: - Segment Content

    @ViewBuilder
    private var segmentContent: some View {
        switch segment {
        case .rankings:
            LeaderboardContent()
        case .friends:
            FriendsListContent()
        }
    }

    // MARK: - Segment

    enum Segment: String, CaseIterable {
        case rankings
        case friends

        var title: String {
            switch self {
            case .rankings: return "Rankings"
            case .friends:  return "Friends"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LeaderboardTabView()
}
