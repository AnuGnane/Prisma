//
//  ArchiveEvent.swift
//  Prisma
//
//  Represents a single historical event used in Archive daily mode.
//  Loaded from archive_events.json.
//

import Foundation

struct ArchiveEvent: Codable, Identifiable {
    let id: Int
    let day: Int
    let month: Int
    let year: Int
    let hint: String    // shown during play
    let event: String   // revealed after game ends

    /// The 8-digit representation: [D, D, M, M, Y, Y, Y, Y]
    var dateDigits: [Int] {
        let dd = day.formatted(.number.precision(.integerLength(2)))
        let mm = month.formatted(.number.precision(.integerLength(2)))
        let yyyy = year.formatted(.number.precision(.integerLength(4)))
        return (dd + mm + yyyy).compactMap { $0.wholeNumberValue }
    }

    /// Formatted display string: "DD/MM/YYYY"
    var dateString: String {
        "\(day.formatted(.number.precision(.integerLength(2))))/\(month.formatted(.number.precision(.integerLength(2))))/\(year.formatted(.number.precision(.integerLength(4))))"
    }

    /// YYYYMMDD integer for arrow comparison.
    var numericValue: Int {
        year * 10_000 + month * 100 + day
    }
}
