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
                specialKey(label: "⌫", color: Color(red: 1, green: 0.45, blue: 0.45)) {
                    viewModel.deleteLastDigit()
                }
                numberKey(0)
                specialKey(
                    label: "✓",
                    color: viewModel.isInputComplete
                        ? Color(red: 0.24, green: 0.65, blue: 0.36)
                        : Color.white.opacity(0.15),
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
                .foregroundStyle(keyState == .absent ? Color.white.opacity(0.22) : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(keyState == .absent ? Color(white: 0.10) : Color.white.opacity(0.10))
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
                .foregroundStyle(disabled ? Color.white.opacity(0.25) : .white)
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
        Color(red: 0.07, green: 0.07, blue: 0.10).ignoresSafeArea()
        VStack {
            Spacer()
            ArchiveInputView(viewModel: vm) { }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }
}
