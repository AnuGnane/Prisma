//
//  TargetWordListView.swift
//  Prisma
//
//  Displays target words — all visible at start, with completion styling.
//

import SwiftUI

struct TargetWordListView: View {
    let targetWords: [TargetWord]
    let completedWords: Set<UUID>
    let hintWord: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FIND \(targetWords.count) WORDS")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .kerning(1.5)

                Spacer()

                Text("\(completedWords.count)/\(targetWords.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(completedWords.count == targetWords.count ? .green : .white.opacity(0.5))
            }

            FlowLayout(spacing: 8) {
                ForEach(targetWords) { word in
                    wordChip(word)
                }
            }
        }
    }

    @ViewBuilder
    private func wordChip(_ word: TargetWord) -> some View {
        let done = completedWords.contains(word.id)

        HStack(spacing: 6) {
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
            }

            // Always show the word text
            Text(word.word)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(done ? .green : .white)
                .strikethrough(done, color: .green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(
                done ? Color.green.opacity(0.12) : Color.white.opacity(0.06)
            )
        )
        .overlay(
            Capsule().strokeBorder(
                done ? Color.green.opacity(0.3) : Color.white.opacity(0.08),
                lineWidth: 1
            )
        )
        .scaleEffect(done ? 0.95 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: done)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rh: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > w && x > 0 { y += rh + spacing; x = 0; rh = 0 }
            x += sz.width + spacing; rh = max(rh, sz.height)
        }
        return CGSize(width: w, height: y + rh)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rh: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX { y += rh + spacing; x = bounds.minX; rh = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing; rh = max(rh, sz.height)
        }
    }
}
