//
//  SerializableSignalsState.swift
//  Prisma
//
//  Serializable data structures for persisting Signals game state.
//

import Foundation

/// Serializable representation of a single Signals guess with feedback
struct SerializableSignalsGuess: Codable {
    let digits: [Int]
    let digitResults: [String]  // Position-specific: "correct", "misplaced", or "absent"
}

/// Serializable representation of the complete Signals guess history
struct SerializableSignalsState: Codable {
    let guesses: [SerializableSignalsGuess]
}
