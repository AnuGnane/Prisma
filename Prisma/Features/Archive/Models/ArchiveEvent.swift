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
        let dd = String(format: "%02d", day)
        let mm = String(format: "%02d", month)
        let yyyy = String(format: "%04d", year)
        return (dd + mm + yyyy).compactMap { $0.wholeNumberValue }
    }

    /// Formatted display string: "DD/MM/YYYY"
    var dateString: String {
        String(format: "%02d/%02d/%04d", day, month, year)
    }

    /// YYYYMMDD integer for arrow comparison.
    var numericValue: Int {
        year * 10_000 + month * 100 + day
    }
}
