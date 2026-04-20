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
                        Text("Life is more fun with puzzles. ✨")
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
        }
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
