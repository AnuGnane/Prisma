//
//  SignalsGameView.swift
//  Prisma
//
//  Main container for a Signals game session.
//  Board: fixed maxGuesses rows — past guesses show feedback,
//  the current row shows live input, future rows are empty placeholders.
//  Keypad always anchored to the bottom.
//

import SwiftUI

struct SignalsGameView: View {
    @State private var viewModel: SignalsGameViewModel
    @State private var showResultSheet = false

    init(viewModel: SignalsGameViewModel = SignalsGameViewModel(date: .now)) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 4)
                    .padding(.bottom, 14)

                // Fixed board — all maxGuesses rows always visible
                board
                    .padding(.horizontal, 24)

                Spacer(minLength: 8)

                // Keypad always at bottom (hidden when game is over)
                if !viewModel.gameState.isOver {
                    SignalsInputView(viewModel: viewModel) {
                        viewModel.submitGuess()
                        if viewModel.gameState.isOver {
                            withAnimation(.spring(response: 0.4)) {
                                showResultSheet = true
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showResultSheet) {
            resultSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                Text("SIGNALS")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .kerning(3)

                // Guess counter pill
                Text("\(viewModel.guessCount) / \(viewModel.maxGuesses)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)

            // 🛠 Debug reset — remove before shipping
            Button {
                viewModel.overrideForTesting(
                    secret: SignalsCode(fromSeed: Date.now.dailySeed),
                    maxGuesses: 5
                )
                showResultSheet = false
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(8)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
    }

    // MARK: - Board

    /// Fixed grid: for each row index 0..<maxGuesses, render the appropriate row type.
    private var board: some View {
        VStack(spacing: 8) {
            ForEach(0..<viewModel.maxGuesses, id: \.self) { rowIndex in
                if rowIndex < viewModel.guessHistory.count {
                    // Submitted guess — show feedback
                    let entry = viewModel.guessHistory[rowIndex]
                    SignalsFeedbackRow(guess: entry.guess, feedback: entry.feedback)
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom),
                            removal: .opacity
                        ))
                } else if rowIndex == viewModel.guessHistory.count && !viewModel.gameState.isOver {
                    // Active input row — live digits from currentInput
                    activeInputRow
                } else {
                    // Future / unfilled row
                    emptyRow
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.guessCount)
    }

    // MARK: - Active Input Row

    private var activeInputRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                let digit = viewModel.currentInput[index]
                let isNextEmpty = digit == nil && index == firstEmptyInputSlot
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            digit != nil
                                ? Color.white.opacity(0.8)
                                : (isNextEmpty ? Color.white.opacity(0.50) : Color.white.opacity(0.18)),
                            lineWidth: isNextEmpty ? 2.5 : 2
                        )
                        .frame(width: 58, height: 58)

                    if let d = digit {
                        Text("\(d)")
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.12), value: digit)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.12), value: viewModel.currentInput.map { $0 ?? -1 })
    }

    private var firstEmptyInputSlot: Int {
        viewModel.currentInput.firstIndex(of: nil) ?? 4
    }

    // MARK: - Empty Row

    private var emptyRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 2)
                    .frame(width: 58, height: 58)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Result Sheet

    private var resultSheet: some View {
        VStack(spacing: 20) {
            Spacer()

            let didWin = viewModel.gameState.isCompleted
            Image(systemName: didWin ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(didWin
                    ? Color(red: 0.24, green: 0.65, blue: 0.36)
                    : Color(red: 0.85, green: 0.30, blue: 0.30))
                .symbolEffect(.bounce, value: showResultSheet)

            Text(didWin ? "Signal Locked!" : "Signal Lost")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)

            if !didWin {
                let secret = viewModel.secretCode.digits.map { "\($0)" }.joined(separator: " ")
                Text("The code was: \(secret)")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            let shareString = viewModel.generateShareString()
            ShareLink(item: shareString) {
                Label("Share Result", systemImage: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            if !viewModel.isDaily {
                Button("Play Again") {
                    showResultSheet = false
                    viewModel = SignalsGameViewModel(date: .now)
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.fraction(0.50)])
        .presentationCornerRadius(24)
    }
}

#Preview("Daily — In Progress") {
    SignalsGameView()
}

#Preview("Mid-game with key states") {
    let vm = SignalsGameViewModel(date: .now)
    vm.overrideForTesting(secret: SignalsCode(digits: [1, 2, 3, 4]), maxGuesses: 5)
    vm.currentInput = [9, 9, 9, 9]; vm.submitGuess()
    vm.currentInput = [5, 1, 7, 8]; vm.submitGuess()
    return SignalsGameView(viewModel: vm)
}

#Preview("Completed") {
    let vm = SignalsGameViewModel(date: .now)
    vm.overrideForTesting(secret: SignalsCode(digits: [1, 2, 3, 4]), maxGuesses: 5)
    vm.currentInput = [9, 9, 9, 9]; vm.submitGuess()
    vm.currentInput = [1, 2, 3, 4]; vm.submitGuess()
    return SignalsGameView(viewModel: vm)
}
