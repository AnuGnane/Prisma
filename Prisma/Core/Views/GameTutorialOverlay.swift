//
//  GameTutorialOverlay.swift
//  Prisma
//
//  Brief rules overlay shown on first play of each game.
//  Auto-dismissed on tap or after reading.
//

import SwiftUI

struct GameTutorialOverlay: View {
    let gameType: GameType
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                Image(systemName: iconForGame)
                    .font(.system(size: 44))
                    .foregroundStyle(colorForGame)

                Text("HOW TO PLAY")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.5))
                    .kerning(3)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rules, id: \.self) { rule in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(colorForGame)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(rule)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 8)

                Button {
                    onDismiss()
                } label: {
                    Text("GOT IT")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(colorForGame))
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
        }
    }

    private var rules: [String] {
        switch gameType {
        case .signals:
            return [
                "Crack the 4-digit secret code in 5 guesses or fewer.",
                "Green = correct digit in correct position.",
                "Yellow = correct digit, wrong position.",
                "Grey = digit not in the code.",
                "Use the arrow hint (↑↓) to tell if your number is too high or low."
            ]
        case .archive:
            return [
                "Guess the date of a historical event (DD/MM/YYYY).",
                "Green = correct digit in correct position.",
                "Yellow = correct digit, wrong position.",
                "Use the arrow hint to narrow down the date.",
                "You have 7 guesses. Invalid dates don't count!"
            ]
        case .cargo:
            return [
                "Fill the cargo grid by placing all puzzle pieces.",
                "Drag pieces from the tray onto the grid.",
                "Rotate and flip pieces to find the right fit.",
                "You can undo up to 3 placements.",
                "Score is based on how much of the grid you fill."
            ]
        case .shift:
            return [
                "Slide rows and columns to form hidden words.",
                "Swipe horizontally to shift a row, vertically for a column.",
                "Words can appear anywhere on the board.",
                "Found words highlight and lock in place.",
                "Find all words to complete the puzzle!"
            ]
        default:
            return ["Coming soon!"]
        }
    }

    private var iconForGame: String {
        switch gameType {
        case .signals: return "antenna.radiowaves.left.and.right"
        case .archive: return "clock.arrow.circlepath"
        case .cargo:   return "shippingbox.fill"
        case .shift:   return "slider.horizontal.3"
        default:       return "star.fill"
        }
    }

    private var colorForGame: Color {
        switch gameType {
        case .signals: return AppTheme.signals
        case .archive: return AppTheme.archive
        case .cargo:   return AppTheme.cargo
        case .shift:   return AppTheme.shift
        default:       return .primary
        }
    }
}

/// Helper view modifier to show tutorial on first play.
struct TutorialOverlayModifier: ViewModifier {
    let gameType: GameType
    @AppStorage private var hasSeenTutorial: Bool

    init(gameType: GameType) {
        self.gameType = gameType
        _hasSeenTutorial = AppStorage(wrappedValue: false, "tutorial.\(gameType.rawValue).seen")
    }

    func body(content: Content) -> some View {
        content.overlay {
            if !hasSeenTutorial {
                GameTutorialOverlay(gameType: gameType) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        hasSeenTutorial = true
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

extension View {
    func showTutorialOnFirstPlay(for gameType: GameType) -> some View {
        modifier(TutorialOverlayModifier(gameType: gameType))
    }
}

#Preview {
    Color.black
        .overlay {
            GameTutorialOverlay(gameType: .signals) { }
        }
}
