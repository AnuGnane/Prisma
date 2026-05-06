//
//  DailySweepView.swift
//  Prisma
//
//  Shown once per day when the player completes all 5 daily puzzles.
//  Displays per-game metrics and aggregate stats.
//

import SwiftUI

// MARK: - DailySweepView

struct DailySweepView: View {
    /// Exactly the 5 daily GameResults that triggered this sweep.
    let results: [GameResult]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var shareableImage: ShareableImage?

    // MARK: - Derived

    /// All 5 game types in display order.
    private static let displayOrder: [GameType] = [.signals, .archive, .cargo, .shift, .circuit]

    private var orderedResults: [(game: GameType, result: GameResult?)] {
        Self.displayOrder.map { game in
            (game, results.first { $0.gameType == game })
        }
    }

    private var totalDurationSeconds: Int {
        Int(results.reduce(0) { $0 + $1.durationSeconds })
    }

    private var totalDurationFormatted: String {
        let total = totalDurationSeconds
        if total >= 60 {
            let m = total / 60
            let s = total % 60
            return "\(m):\(s.formatted(.number.precision(.integerLength(2))))"
        }
        return "\(total)s"
    }

    /// Perfect clears: Signals/Archive solved on first guess, Cargo fully packed.
    private var perfectClears: Int {
        results.filter { result in
            switch result.gameType {
            case .signals, .archive: return result.guessCount == 1
            case .cargo:             return result.score == 1000  // 100% fill
            case .shift, .circuit:   return false                 // not determinable from stored data
            }
        }.count
    }

    private var winsCount: Int {
        results.filter { $0.score > 0 }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppTheme.appBackground()

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 52))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: AppTheme.brandGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(appeared ? 1.0 : 0.6)
                            .opacity(appeared ? 1 : 0)

                        Text("Daily Sweep")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("You completed all 5 puzzles today!")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    // Per-game result rows
                    VStack(spacing: 1) {
                        ForEach(orderedResults, id: \.game) { entry in
                            SweepResultRow(game: entry.game, result: entry.result)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Aggregate stats
                    HStack(spacing: 0) {
                        SweepStatCard(
                            icon: "clock",
                            label: "TOTAL TIME",
                            value: totalDurationFormatted
                        )
                        Divider()
                            .frame(height: 48)
                            .background(Color.primary.opacity(0.1))
                        SweepStatCard(
                            icon: "star.fill",
                            label: "PERFECT CLEARS",
                            value: "\(perfectClears)"
                        )
                        Divider()
                            .frame(height: 48)
                            .background(Color.primary.opacity(0.1))
                        SweepStatCard(
                            icon: "checkmark.circle.fill",
                            label: "GAMES WON",
                            value: "\(winsCount)/5"
                        )
                    }
                    .padding(.vertical, 16)
                    .background(Color.primary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Share + dismiss
                    VStack(spacing: 12) {
                        if let img = shareableImage {
                            ShareLink(item: img, preview: SharePreview("Prisma Daily Sweep", image: Image(uiImage: img.image))) {
                                Label("Share Your Sweep", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        Capsule().fill(
                                            LinearGradient(
                                                colors: AppTheme.brandGradient,
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    )
                            }
                        } else {
                            // Share card is rendering — show a subtle placeholder
                            Label("Preparing Share Card…", systemImage: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule().fill(Color.primary.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                    appeared = true
                }
            }
            // Pre-render the share card on first appear (MainActor, ~few ms)
            if shareableImage == nil, let uiImage = ShareCardRenderer.render(results: results) {
                shareableImage = ShareableImage(image: uiImage)
            }
        }
    }

    // MARK: - Share Text

    private var sweepShareText: String? {
        var lines: [String] = ["Prisma Daily Sweep 🌈"]
        for entry in orderedResults {
            guard let r = entry.result else { continue }
            let icon = entry.game.emoji
            let metric = r.score > 0 ? r.formattedMetric : "—"
            lines.append("\(icon) \(entry.game.displayName): \(metric)")
        }
        lines.append("Total time: \(totalDurationFormatted)")
        if perfectClears > 0 {
            lines.append("⭐ \(perfectClears) perfect \(perfectClears == 1 ? "clear" : "clears")")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - SweepResultRow

private struct SweepResultRow: View {
    let game: GameType
    let result: GameResult?

    private var gameColor: Color { AppTheme.accent(for: game) }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(result.map { $0.score > 0 ? gameColor : Color.secondary.opacity(0.3) } ?? Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)

            Text(game.displayName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            if let result {
                Text(result.score > 0 ? result.formattedMetric : "Lost")
                    .font(.callout.weight(.medium).monospaced())
                    .foregroundStyle(result.score > 0 ? gameColor : .secondary)
            } else {
                Text("—")
                    .font(.callout.weight(.medium).monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.08))
    }
}

// MARK: - SweepStatCard

private struct SweepStatCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Detection Helper (testable)

/// Determines whether a set of today's daily results constitutes a "Daily Sweep":
/// all 5 games completed (score > 0, i.e. won).
///
/// This function is `static` so it can be imported and unit-tested without
/// spinning up a SwiftUI view.
extension DailySweepView {
    static func isSweep(_ results: [GameResult]) -> Bool {
        guard results.count >= 5 else { return false }
        let gameTypes = Set(results.filter { $0.score > 0 }.map { $0.gameType })
        return GameType.allCases.allSatisfy { gameTypes.contains($0) }
    }
}

// MARK: - Preview

#Preview {
    let signals  = GameResult(gameType: .signals,  score: 900, shareString: "", guessCount: 3,  isDaily: true, durationSeconds: 0)
    let archive  = GameResult(gameType: .archive,  score: 800, shareString: "", guessCount: 1,  isDaily: true, durationSeconds: 0)
    let cargo    = GameResult(gameType: .cargo,    score: 870, shareString: "", guessCount: 0,  isDaily: true, durationSeconds: 47)
    let shift    = GameResult(gameType: .shift,    score: 750, shareString: "", guessCount: 12, isDaily: true, durationSeconds: 68)
    let circuit  = GameResult(gameType: .circuit,  score: 960, shareString: "", guessCount: 24, isDaily: true, durationSeconds: 95)
    DailySweepView(results: [signals, archive, cargo, shift, circuit])
}
