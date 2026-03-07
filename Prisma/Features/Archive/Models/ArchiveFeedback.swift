//
//  ArchiveFeedback.swift
//  Prisma
//
//  Feedback for a single Archive guess — 8 per-digit results + arrow hint.
//  Reuses DigitResult and ValueHint from the Signals module.
//

import Foundation

struct ArchiveFeedback: Equatable {
    /// Per-digit result for all 8 positions.
    let digitResults: [DigitResult]   // length 8
    /// High / Low / Exact hint based on full date comparison.
    let valueHint: ValueHint

    /// True when all 8 digits are correct.
    var isWin: Bool {
        digitResults.allSatisfy { $0 == .correct }
    }
}
