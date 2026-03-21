//
//  SignalsInputView.swift
//  Prisma
//
//  Keypad only — no separate input row.
//  The active guess row lives directly in the board (SignalsGameView).
//  Bottom row: ⌫ · 0 · ✓
//

import SwiftUI

struct SignalsInputView: View {
    @Bindable var viewModel: SignalsGameViewModel
    var onSubmit: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let numericRows: [[Int]] = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<numericRows.count, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(numericRows[row], id: \.self) { digit in
                        numberKey(digit)
                    }
                }
            }
            // Bottom row: ⌫ · 0 · ✓
            HStack(spacing: 8) {
                specialKey(title: "Delete", systemImage: "delete.left.fill", color: AppTheme.deleteRed) {
                    viewModel.deleteLastDigit()
                }
                numberKey(0)
                specialKey(
                    title: "Submit",
                    systemImage: "checkmark",
                    color: viewModel.isInputComplete
                        ? AppTheme.signals
                        : AppTheme.dimText,
                    disabled: !viewModel.isInputComplete,
                    action: onSubmit
                )
            }
        }
    }

    // MARK: - Key Builders

    @ViewBuilder
    private func numberKey(_ digit: Int) -> some View {
        let keyState = viewModel.digitKeyStates[digit] ?? .unknown
        Button {
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.08)) {
                Haptics.playLightImpact()
                viewModel.inputDigit(digit)
            }
        } label: {
            Text("\(digit)")
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(keyState == .absent ? AppTheme.dimText : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(keyState == .absent ? AppTheme.keyFill : AppTheme.keyFill)
                )
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: keyState)
    }

    @ViewBuilder
    private func specialKey(
        title: String,
        systemImage: String,
        color: Color,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.playLightImpact()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(disabled ? AppTheme.dimText : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: disabled)
    }
}

#Preview("Keypad — no history") {
    @Previewable @State var vm = SignalsGameViewModel(date: .now)
    ZStack {
        AppTheme.backgroundSecondary.ignoresSafeArea()
        VStack {
            Spacer()
            SignalsInputView(viewModel: vm) { }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }
}

#Preview("Keypad — with guess history") {
    @Previewable @State var vm = SignalsGameViewModel(date: .now)
    let _ = {
        vm.overrideForTesting(secret: SignalsCode(digits: [1,2,3,4]), maxGuesses: 5)
        vm.currentInput = [9,9,9,9]; vm.submitGuess()
        vm.currentInput = [5,1,7,8]; vm.submitGuess()
    }()
    ZStack {
        AppTheme.backgroundSecondary.ignoresSafeArea()
        VStack {
            Spacer()
            SignalsInputView(viewModel: vm) { }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }
}
