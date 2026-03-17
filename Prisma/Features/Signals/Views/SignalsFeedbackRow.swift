//
//  SignalsFeedbackRow.swift
//  Prisma
//
//  Displays one completed guess row with a staggered tile-flip reveal animation.
//  Each of the 4 digit cells flips in with a 150ms delay between tiles.
//  The High/Low/Exact hint fades in after all tiles have flipped.
//

import SwiftUI

struct SignalsFeedbackRow: View {
    let guess: SignalsGuess
    let feedback: SignalsFeedback

    /// One Bool per tile — drives the flip from unrevealed → colour-revealed.
    @State private var revealed = [false, false, false, false]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                flipCell(index: index)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            valueHintLabel
                .frame(width: 36)
                // Hint appears after the last tile has flipped
                .opacity(revealed[3] ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: revealed[3])
        }
        .onAppear {
            for i in 0..<4 {
                let delay = Double(i) * 0.15
                withAnimation(
                    .easeInOut(duration: 0.35)
                    .delay(delay)
                ) {
                    revealed[i] = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.15) {
                    Haptics.playRigidImpact()
                }
            }
        }
    }

    // MARK: - Flip Cell

    @ViewBuilder
    private func flipCell(index: Int) -> some View {
        let isRevealed = revealed[index]
        let result = feedback.digitResults[index]

        ZStack {
            // ── Front face: unrevealed placeholder ──
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AppTheme.cellBorder, lineWidth: 2)
                .frame(width: 58, height: 58)
                // Rotate away (0° → 90°) and fade out
                .rotation3DEffect(.degrees(isRevealed ? 90 : 0),
                                  axis: (x: 0, y: 1, z: 0))
                .opacity(isRevealed ? 0 : 1)

            // ── Back face: coloured result cell ──
            Text("\(guess.digits[index])")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 58, height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(cellColor(for: result))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(cellColor(for: result).opacity(0.6), lineWidth: 1)
                )
                // Rotate in (−90° → 0°) and fade in
                .rotation3DEffect(.degrees(isRevealed ? 0 : -90),
                                  axis: (x: 0, y: 1, z: 0))
                .opacity(isRevealed ? 1 : 0)
        }
    }

    // MARK: - Helpers

    private func cellColor(for result: DigitResult) -> Color {
        switch result {
        case .correct:   return AppTheme.signals
        case .misplaced: return AppTheme.misplacedWarm
        case .absent:    return Color.primary.opacity(0.30)
        }
    }

    @ViewBuilder
    private var valueHintLabel: some View {
        switch feedback.valueHint {
        case .high:
            Image(systemName: "arrow.down.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.error)
                .font(.title2)
        case .low:
            Image(systemName: "arrow.up.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.archive)
                .font(.title2)
        case .exact:
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.signals)
                .font(.title2)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SignalsFeedbackRow(
            guess: SignalsGuess(digits: [5, 4, 4, 1]),
            feedback: SignalsFeedback(
                digitResults: [.correct, .misplaced, .absent, .absent],
                valueHint: .high
            )
        )
        SignalsFeedbackRow(
            guess: SignalsGuess(digits: [1, 2, 3, 4]),
            feedback: SignalsFeedback(
                digitResults: [.correct, .correct, .correct, .correct],
                valueHint: .exact
            )
        )
    }
    .padding()
    .background(Color.black)
}
