//
//  ContentView.swift
//  Prisma
//
//  Main entry point and Home screen.
//  Provides a TabView for Daily vs Local game selection.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Daily", systemImage: "sun.max.fill") {
                gameList(isDaily: true)
            }
            
            Tab("Local", systemImage: "folder.fill") {
                gameList(isDaily: false)
            }
        }
        .tint(.white)
        .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.10), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
    
    // MARK: - Game List
    
    @ViewBuilder
    private func gameList(isDaily: Bool) -> some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.10)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        
                        Text(isDaily ? "DAILY PUZZLES" : "LOCAL ARCHIVE")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .kerning(1.5)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 16) {
                            GameCard(
                                game: .signals,
                                icon: "antenna.radiowaves.left.and.right",
                                color: Color(red: 0.24, green: 0.65, blue: 0.36),
                                destination: isDaily ? AnyView(SignalsGameView()) : AnyView(LevelSelectorView(game: .signals))
                            )
                            
                            GameCard(
                                game: .archive,
                                icon: "clock.arrow.circlepath",
                                color: Color(red: 0.24, green: 0.52, blue: 0.85),
                                destination: isDaily ? AnyView(ArchiveGameView()) : AnyView(LevelSelectorView(game: .archive))
                            )

                            DisabledGameCard(game: .cargo, icon: "shippingbox.fill")
                            DisabledGameCard(game: .shift, icon: "slider.horizontal.3")
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prisma")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            
            Text("Your daily cognitive signal.")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Game Card

struct GameCard: View {
    let game: GameType
    let icon: String
    let color: Color
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination.navigationBarBackButtonHidden(false).tint(.white)) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 54, height: 54)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text(game.description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
    }
}

// MARK: - Disabled Game Card

struct DisabledGameCard: View {
    let game: GameType
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.15))
                    .frame(width: 54, height: 54)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(game.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text("SOON")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }
                
                Text(game.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.02), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}
