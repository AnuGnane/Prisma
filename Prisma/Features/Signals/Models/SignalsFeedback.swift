//
//  SignalsFeedback.swift
//  Prisma
//
//  Feedback produced for each guess:
//  - Per-digit color result (correct position / right digit wrong spot / absent)
//  - ValueHint comparing guess vs secret as full numbers (High / Low / Exact)
//

import Foundation

/// Result for a single digit position in a guess.
enum DigitResult: Equatable {
    /// Correct digit in the correct position (green)
    case correct
    /// Correct digit but in the wrong position (yellow)
    case misplaced
    /// Digit not in the secret code at all (grey)
    case absent
}

/// Hint based on comparing the guess number vs the secret number.
/// e.g. guess 5441 vs secret 3215 → .high ("your number is too high")
enum ValueHint: Equatable {
    case high   // guess > secret → arrow pointing down (go lower)
    case low    // guess < secret → arrow pointing up (go higher)
    case exact  // guess == secret (same as all-correct)
}

struct SignalsFeedback: Equatable {
    /// One `DigitResult` per digit position (length 4).
    let digitResults: [DigitResult]
    /// Comparison hint based on full numeric value.
    let valueHint: ValueHint

    var isWin: Bool {
        digitResults.allSatisfy { $0 == .correct }
    }
}
