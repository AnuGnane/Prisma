//
//  CircuitResultView.swift
//  Prisma
//
//  Completion overlay shown when all Circuit terminals are powered.
//  Shows 1–3 star rating, time, coverage, efficiency — no numeric score.
//  Share uses a wordle-style emoji grid (stars only, no number).
//

import SwiftUI

struct CircuitResultView: View {
    let viewModel: CircuitGameViewModel
    let stars: Int
    let onDone: () -> Void
    let onNextLevel: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedStars: Int = 0

    private let accentColor = Color(red: 0.0, green: 0.78, blue: 1.0) // circuit cyan

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Text(headerTitle)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)

            // Star display
            HStack(spacing: 12) {
                ForEach(1...3, id: \.self) { i in
                    Image(systemName: i <= revealedStars ? "star.fill" : "star")
                        .font(.system(size: 36))
                        .foregroundStyle(i <= revealedStars ? .yellow : .primary.opacity(0.2))
                        .scaleEffect(i <= revealedStars ? 1.1 : 1.0)
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6).delay(Double(i - 1) * 0.2),
                            value: revealedStars
                        )
                }
            }
            .padding(.vertical, 28)

            // Stats row
            HStack(spacing: 0) {
                StatCell(label: "Time", value: viewModel.timerString)
                Divider().frame(height: 36)
                StatCell(label: "Coverage", value: "\(Int(viewModel.coveragePercent * 100))%")
                Divider().frame(height: 36)
                StatCell(label: "Efficiency", value: efficiencyText)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            Divider().padding(.horizontal, 24)

            // Actions
            VStack(spacing: 12) {
                // Share button
                ShareLink(item: viewModel.generateShareString()) {
                    Label("Share Result", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(accentColor.opacity(0.12))
                        )
                }

                HStack(spacing: 12) {
                    // Done
                    Button("Done", action: onDone)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.primary.opacity(0.07))
                        )

                    // Next level (local progression only)
                    if let onNext = onNextLevel {
                        Button("Next Level →", action: onNext)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(accentColor)
                            )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 24)
        .onAppear {
            if reduceMotion {
                revealedStars = stars
            } else {
                revealStarsSequentially()
            }
        }
    }

    // MARK: - Helpers

    private var headerTitle: String {
        switch stars {
        case 3: return "Max Efficiency! ⚡"
        case 2: return "Perfect Flow! ✓"
        default: return "Circuit Complete!"
        }
    }

    private var headerSubtitle: String {
        switch stars {
        case 3: return "Optimal solution — all cells used"
        case 2: return "All cells covered"
        default: return "All terminals powered"
        }
    }

    private var efficiencyText: String {
        let par = viewModel.level.parPathLength
        let used = viewModel.totalPathLength
        if par > 0 {
            return "\(used)/\(par)"
        }
        return "–"
    }

    private func revealStarsSequentially() {
        for i in 1...stars {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - 1) * 0.35) {
                withAnimation { revealedStars = i }
                Haptics.playLightImpact()
            }
        }
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
