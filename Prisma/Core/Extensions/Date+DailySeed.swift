//
//  Date+DailySeed.swift
//  Prisma
//
//  Generates a deterministic integer seed from the calendar date (local time).
//  The seed resets at local midnight, giving every player the same daily puzzle.
//

import Foundation

extension Date {
    /// Returns a deterministic seed integer for the current calendar day (local timezone).
    /// Format: yyyyMMdd as an Int — e.g. 20260227 for Feb 27 2026.
    var dailySeed: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        let year  = components.year  ?? 2026
        let month = components.month ?? 1
        let day   = components.day   ?? 1
        return year * 10_000 + month * 100 + day
    }

    /// True if this date falls on the same calendar day as `other` (local timezone).
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
