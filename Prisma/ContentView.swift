//
//  ContentView.swift
//  Prisma
//
//  Root TabView — routes to Games, Leaderboard, and You tabs.
//
//  GKAccessPoint is shown only on Leaderboard and You tabs to keep game
//  screens distraction-free. The Leaderboard tab manages its own GKAccessPoint
//  lifecycle (see LeaderboardTabView); this view handles only the You tab's
//  toggle plus the default-inactive state on the Games tab.
//

import SwiftUI
import SwiftData
import GameKit

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Games", systemImage: "house.fill") {
                GamesHomeView()
                    .onAppear  { GKAccessPoint.shared.isActive = false }
            }

            Tab("Leaderboard", systemImage: "trophy.fill") {
                LeaderboardTabView()
            }

            Tab("You", systemImage: "person.fill") {
                ProfileView()
                    .onAppear  { GKAccessPoint.shared.isActive = true }
                    .onDisappear { GKAccessPoint.shared.isActive = false }
            }
        }
        // On iOS 26 the Tab bar automatically receives Liquid Glass treatment.
        // Avoid suppressing it with custom toolbarBackground calls.
        .tint(.primary)
        .onAppear {
            // One-time setup: position top-leading, start inactive.
            GKAccessPoint.shared.location = .topLeading
            GKAccessPoint.shared.isActive = false
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}
