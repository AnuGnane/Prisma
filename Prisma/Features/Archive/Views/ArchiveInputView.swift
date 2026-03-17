//
//  ArchiveInputView.swift
//  Prisma
//
//  Keypad for Archive — same 0-9 layout as Signals.
//  Bottom row: ⌫ · 0 · ✓
//

import SwiftUI

struct ArchiveInputView: View {
    @Bindable var viewModel: ArchiveGameViewModel
    var onSubmit: () -> Void

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
            HStack(spacing: 8) {
                specialKey(label: "⌫", color: AppTheme.deleteRed) {
                    viewModel.deleteLastDigit()
                }
                numberKey(0)
                specialKey(
                    label: "✓",
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
            withAnimation(.easeIn(duration: 0.08)) {
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
        .animation(.easeInOut(duration: 0.25), value: keyState)
    }

    @ViewBuilder
    private func specialKey(
        label: String,
        color: Color,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.playLightImpact()
            action()
        } label: {
            Text(label)
                .font(.system(size: 22, weight: .semibold))
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
        .animation(.easeInOut(duration: 0.2), value: disabled)
    }
}

#Preview {
    @Previewable @State var vm = ArchiveGameViewModel(date: .now)
    ZStack {
        AppTheme.backgroundSecondary.ignoresSafeArea()
        VStack {
            Spacer()
            ArchiveInputView(viewModel: vm) { }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }
}
