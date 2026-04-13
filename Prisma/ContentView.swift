//
//  ContentView.swift
//  Prisma
//
//  Root TabView — routes to Games, Friends, and Profile tabs.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Games", systemImage: "house.fill") {
                GamesHomeView()
            }

            Tab("Friends", systemImage: "person.2.fill") {
                FriendsPlaceholderView()
            }

            Tab("You", systemImage: "person.fill") {
                ProfileView()
            }
        }
        // On iOS 26 the Tab bar automatically receives Liquid Glass treatment.
        // Avoid suppressing it with custom toolbarBackground calls.
        .tint(.primary)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}
