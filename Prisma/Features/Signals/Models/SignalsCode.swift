//
//  SignalsCode.swift
//  Prisma
//
//  The hidden 4-digit code the player is trying to deduce.
//  Digits are 0–9, duplicates allowed.
//

import Foundation

struct SignalsCode: Equatable {
    let digits: [Int]   // Always length 4

    /// The code interpreted as a full 4-digit integer for High/Low comparison.
    /// e.g. [3, 2, 1, 5] → 3215
    var numericValue: Int {
        digits.reduce(0) { $0 * 10 + $1 }
    }

    // MARK: - Initialisers

    /// Creates a code from an explicit digit array. Must be length 4, digits 0–9.
    init(digits: [Int]) {
        precondition(digits.count == 4, "SignalsCode requires exactly 4 digits")
        precondition(digits.allSatisfy { $0 >= 0 && $0 <= 9 }, "Digits must be 0–9")
        self.digits = digits
    }

    /// Creates a deterministic code from an integer seed (e.g. today's daily seed).
    /// Uses a simple LCG so the same seed always produces the same code.
    init(fromSeed seed: Int) {
        self.init(fromSeed: seed, digitRange: 0...9)
    }

    /// Creates a deterministic code from an integer seed, restricting digits
    /// to the given closed range. Used for progression levels where the
    /// level config narrows the digit set (e.g. 1...6 for novice puzzles).
    ///
    /// The range must be within 0...9 because `SignalsCode` still only
    /// accepts digits 0–9; validation enforces this in `init(digits:)`.
    init(fromSeed seed: Int, digitRange: ClosedRange<Int>) {
        let clamped = max(0, digitRange.lowerBound)...min(9, digitRange.upperBound)
        var rng = SeededGenerator(seed: seed)
        let d = (0..<4).map { _ in Int.random(in: clamped, using: &rng) }
        self.init(digits: d)
    }
}

// MARK: - Seeded RNG

/// A simple, deterministic linear-congruential generator (LCG).
/// Not cryptographically secure — only used for reproducible puzzle seeds.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
    }

    mutating func next() -> UInt64 {
        // LCG parameters from Knuth (MMIX)
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
