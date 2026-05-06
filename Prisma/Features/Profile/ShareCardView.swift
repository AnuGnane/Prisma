//
//  ShareCardView.swift
//  Prisma
//
//  A self-contained card view designed to be rendered to a UIImage by
//  ShareCardRenderer and then shared via the system share sheet.
//
//  Design constraints:
//  • Fixed 400 × 520 pt canvas (rendered @3x → 1200 × 1560 px)
//  • Dark background so it looks great in both dark and light contexts
//  • Uses only static SF Symbols + app colours — no SwiftData dependencies
//

import SwiftUI

// MARK: - ShareCardView

struct ShareCardView: View {
    let results: [GameResult]

    private static let displayOrder: [GameType] = [.signals, .archive, .cargo, .shift, .circuit]

    private var orderedRows: [(game: GameType, result: GameResult?)] {
        Self.displayOrder.map { game in
            (game, results.first { $0.gameType == game })
        }
    }

    private var dateString: String {
        Date.now.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.07, green: 0.07, blue: 0.10)

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("PRISMA")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .kerning(4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: AppTheme.brandGradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text(dateString)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Game rows
                VStack(spacing: 2) {
                    ForEach(orderedRows, id: \.game) { entry in
                        ShareCardRow(game: entry.game, result: entry.result)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Footer
                Text("prisma.app")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 400, height: 520)
        .colorScheme(.dark)
    }
}

// MARK: - ShareCardRow

private struct ShareCardRow: View {
    let game: GameType
    let result: GameResult?

    private var gameColor: Color { AppTheme.accent(for: game) }

    private var metricText: String {
        guard let r = result else { return "—" }
        return r.score > 0 ? r.formattedMetric : "✕"
    }

    private var won: Bool { (result?.score ?? 0) > 0 }

    var body: some View {
        HStack(spacing: 12) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(won ? gameColor : Color.white.opacity(0.1))
                .frame(width: 4, height: 36)

            // Game icon
            Image(systemName: game.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(won ? gameColor : .white.opacity(0.3))
                .frame(width: 24)

            // Game name
            Text(game.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(won ? .white : .white.opacity(0.4))

            Spacer()

            // Metric
            Text(metricText)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(won ? gameColor : .white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview {
    let results: [GameResult] = [
        GameResult(gameType: .signals,  score: 900, shareString: "", guessCount: 3,  isDaily: true, durationSeconds: 0),
        GameResult(gameType: .archive,  score: 800, shareString: "", guessCount: 1,  isDaily: true, durationSeconds: 0),
        GameResult(gameType: .cargo,    score: 870, shareString: "", guessCount: 0,  isDaily: true, durationSeconds: 47),
        GameResult(gameType: .shift,    score: 750, shareString: "", guessCount: 12, isDaily: true, durationSeconds: 68),
        GameResult(gameType: .circuit,  score: 960, shareString: "", guessCount: 24, isDaily: true, durationSeconds: 95),
    ]
    ShareCardView(results: results)
        .frame(width: 400, height: 520)
}
