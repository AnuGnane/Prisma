//
//  SignalsFeedbackRow.swift
//  Prisma
//
//  Displays one completed guess row: 4 digit cells (green/yellow/grey)
//  plus the High/Low/Exact arrow hint on the trailing edge.
//

import SwiftUI

struct SignalsFeedbackRow: View {
    let guess: SignalsGuess
    let feedback: SignalsFeedback

    var body: some View {
        // The 4 digit cells are always centred via maxWidth: .infinity.
        // The hint icon is overlaid at the trailing edge — completely outside
        // the centering calculation — so cells never shift when it appears.
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                digitCell(digit: guess.digits[index], result: feedback.digitResults[index])
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            valueHintLabel
                .frame(width: 36)
        }
    }

    // MARK: - Digit Cell

    @ViewBuilder
    private func digitCell(digit: Int, result: DigitResult) -> some View {
        Text("\(digit)")
            .font(.system(size: 22, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 58, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(cellColor(for: result))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(cellColor(for: result).opacity(0.6), lineWidth: 1)
            )
    }

    private func cellColor(for result: DigitResult) -> Color {
        switch result {
        case .correct:   return Color(red: 0.24, green: 0.65, blue: 0.36)  // green
        case .misplaced: return Color(red: 0.80, green: 0.65, blue: 0.14)  // yellow-amber
        case .absent:    return Color(white: 0.30)                           // dark grey
        }
    }

    // MARK: - Value Hint (High/Low arrow)

    @ViewBuilder
    private var valueHintLabel: some View {
        switch feedback.valueHint {
        case .high:
            Image(systemName: "arrow.down.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color(red: 0.80, green: 0.25, blue: 0.25))
                .font(.title2)
        case .low:
            Image(systemName: "arrow.up.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color(red: 0.24, green: 0.52, blue: 0.85))
                .font(.title2)
        case .exact:
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color(red: 0.24, green: 0.65, blue: 0.36))
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
