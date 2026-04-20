//
//  CircuitResultView.swift
//  Prisma
//
//  Completion overlay shown when all Circuit terminals are powered.
//  Uses ResultOverlayTemplate(.fullScreen) with animated star header,
//  matching the shared overlay pattern used by Shift and other games.
//

import SwiftUI

struct CircuitResultView: View {
    let viewModel: CircuitGameViewModel
    let stars: Int
    let onDone: () -> Void
    let onNextLevel: (() -> Void)?

    var body: some View {
        ResultOverlayTemplate(
            style: .fullScreen,
            header: .stars(title: headerTitle, count: stars),
            stats: [
                ResultStat(label: "Time", value: viewModel.timerString),
                ResultStat(label: "Coverage", value: "\(Int(viewModel.coveragePercent * 100))%")
            ]
        ) {
            EmptyView()
        } actions: {
            VStack(spacing: 12) {
                ResultShareButton(shareString: viewModel.generateShareString())

                HStack(spacing: 12) {
                    ResultSecondaryButton(title: "Done") {
                        onDone()
                    }

                    if let onNext = onNextLevel {
                        ResultPrimaryButton(title: "Next Level →") {
                            onNext()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var headerTitle: String {
        switch stars {
        case 3: return "FULL CIRCUIT ⚡"
        default: return "CIRCUIT COMPLETE"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppTheme.appBackground()
        CircuitResultView(
            viewModel: CircuitGameViewModel(levelId: 1),
            stars: 2,
            onDone: {},
            onNextLevel: {}
        )
    }
}
