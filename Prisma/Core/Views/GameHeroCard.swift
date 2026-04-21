//
//  GameHeroCard.swift
//  Prisma
//
//  NYT-style game card shown on the home feed.
//

import SwiftUI

struct GameHeroCard: View {
    let game: GameType
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    private var gameGradient: [Color] { AppTheme.gradient(for: game) }
    private var gameAccent: Color { AppTheme.accent(for: game) }

    private var todayString: String {
        Date.now.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        NavigationLink(value: GameDetailDestination(game: game)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(game.displayName)
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(game.description)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                    }

                    Spacer()

                    GameCardGraphic(game: game)
                        .frame(width: 72, height: 72)
                        .padding(.top, 4)
                }

                Spacer(minLength: 20)

                Text(todayString)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: gameGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(isPressed ? 0.3 : 0.1), lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .dark ? gameAccent.opacity(isPressed ? 0.15 : 0.25) : .clear,
                radius: isPressed ? 6 : 14,
                x: 0, y: 4
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(CardPressStyle(isPressed: $isPressed))
    }
}

// MARK: - Card Press Button Style (scroll-friendly)

struct CardPressStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}
