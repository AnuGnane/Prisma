//
//  SerializableArchiveState.swift
//  Prisma
//
//  Serializable data structures for persisting Archive game state.
//

import Foundation

/// Serializable representation of a single Archive guess with feedback
struct SerializableArchiveGuess: Codable {
    let digits: [Int]
    let digitResults: [String]  // "correct", "misplaced", or "absent" for each of 8 digits
    let valueHint: String        // "high", "low", or "exact"
}

/// Serializable representation of the complete Archive guess history
struct SerializableArchiveState: Codable {
    let guesses: [SerializableArchiveGuess]
}
