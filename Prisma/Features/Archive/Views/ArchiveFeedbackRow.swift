//
//  ArchiveFeedbackRow.swift
//  Prisma
//
//  Displays one completed Archive guess with staggered tile-flip reveal.
//  8 digits in DD / MM / YYYY grouping with "/" separators.
//

import SwiftUI

struct ArchiveFeedbackRow: View {
    let guess: ArchiveGuess
    let feedback: ArchiveFeedback

    @State private var revealed = Array(repeating: false, count: 8)

    var body: some View {
        HStack(spacing: 0) {
            // DD
            digitGroup(range: 0..<2)
            separator
            // MM
            digitGroup(range: 2..<4)
            separator
            // YYYY
            digitGroup(range: 4..<8)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            valueHintLabel
                .frame(width: 32)
                .opacity(revealed[7] ? 1 : 0)
                .animation(.easeIn(duration: 0.2), value: revealed[7])
        }
        .onAppear {
            for i in 0..<8 {
                let delay = Double(i) * 0.12
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

    // MARK: - Digit Group

    @ViewBuilder
    private func digitGroup(range: Range<Int>) -> some View {
        HStack(spacing: 4) {
            ForEach(range, id: \.self) { index in
                flipCell(index: index)
            }
        }
    }

    // MARK: - Separator

    private var separator: some View {
        Text("/")
            .font(.system(size: 16, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.25))
            .frame(width: 14)
    }

    // MARK: - Flip Cell

    @ViewBuilder
    private func flipCell(index: Int) -> some View {
        let isRevealed = revealed[index]
        let result = feedback.digitResults[index]

        ZStack {
            // Front face: unrevealed
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5)
                .frame(width: 36, height: 42)
                .rotation3DEffect(.degrees(isRevealed ? 90 : 0),
                                  axis: (x: 0, y: 1, z: 0))
                .opacity(isRevealed ? 0 : 1)

            // Back face: coloured result
            Text("\(guess.digits[index])")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 36, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(cellColor(for: result))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(cellColor(for: result).opacity(0.6), lineWidth: 1)
                )
                .rotation3DEffect(.degrees(isRevealed ? 0 : -90),
                                  axis: (x: 0, y: 1, z: 0))
                .opacity(isRevealed ? 1 : 0)
        }
    }

    // MARK: - Helpers

    private func cellColor(for result: DigitResult) -> Color {
        switch result {
        case .correct:   return Color(red: 0.24, green: 0.65, blue: 0.36)
        case .misplaced: return Color(red: 0.80, green: 0.65, blue: 0.14)
        case .absent:    return Color(white: 0.30)
        }
    }

    @ViewBuilder
    private var valueHintLabel: some View {
        switch feedback.valueHint {
        case .high:
            Image(systemName: "arrow.down.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color(red: 0.80, green: 0.25, blue: 0.25))
                .font(.title3)
        case .low:
            Image(systemName: "arrow.up.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color(red: 0.24, green: 0.52, blue: 0.85))
                .font(.title3)
        case .exact:
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color(red: 0.24, green: 0.65, blue: 0.36))
                .font(.title3)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        ArchiveFeedbackRow(
            guess: ArchiveGuess(digits: [2, 0, 0, 7, 1, 9, 6, 9]),
            feedback: ArchiveFeedback(
                digitResults: [.correct, .correct, .misplaced, .absent, .correct, .correct, .correct, .correct],
                valueHint: .exact
            )
        )
        ArchiveFeedbackRow(
            guess: ArchiveGuess(digits: [1, 5, 0, 4, 1, 9, 1, 2]),
            feedback: ArchiveFeedback(
                digitResults: [.absent, .absent, .misplaced, .absent, .correct, .correct, .absent, .absent],
                valueHint: .low
            )
        )
    }
    .padding()
    .background(Color(red: 0.07, green: 0.07, blue: 0.10))
}
