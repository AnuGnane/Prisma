//
//  SignalsGuess.swift
//  Prisma
//

import Foundation

struct SignalsGuess: Equatable {
    let digits: [Int]   // Always length 4, digits 0–9

    /// Full numeric value for High/Low comparison against the secret code.
    var numericValue: Int {
        digits.reduce(0) { $0 * 10 + $1 }
    }

    init(digits: [Int]) {
        precondition(digits.count == 4, "SignalsGuess requires exactly 4 digits")
        self.digits = digits
    }
}
