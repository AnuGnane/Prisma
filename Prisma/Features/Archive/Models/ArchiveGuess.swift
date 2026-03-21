//
//  ArchiveGuess.swift
//  Prisma
//
//  Represents a player's guess in Archive — 8 digits in DD/MM/YYYY format.
//

import Foundation

struct ArchiveGuess: Equatable {
    /// The raw 8 digits: [D, D, M, M, Y, Y, Y, Y]
    let digits: [Int]

    /// The day component (first 2 digits)
    var day: Int { digits[0] * 10 + digits[1] }
    /// The month component (digits 2–3)
    var month: Int { digits[2] * 10 + digits[3] }
    /// The year component (digits 4–7)
    var year: Int { digits[4] * 1000 + digits[5] * 100 + digits[6] * 10 + digits[7] }

    /// YYYYMMDD integer for arrow comparison.
    var numericValue: Int {
        year * 10_000 + month * 100 + day
    }

    /// Formatted display string
    var dateString: String {
        "\(day.formatted(.number.precision(.integerLength(2))))/\(month.formatted(.number.precision(.integerLength(2))))/\(year.formatted(.number.precision(.integerLength(4))))"
    }

    /// Returns true if this guess represents a valid calendar date.
    var isValidDate: Bool {
        guard month >= 1, month <= 12, day >= 1 else { return false }
        guard year >= 1 else { return false }

        let daysInMonth: [Int] = [31, isLeapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return day <= daysInMonth[month - 1]
    }

    private var isLeapYear: Bool {
        (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }
}
