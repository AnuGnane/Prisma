//
//  GameStateSerializer.swift
//  Prisma
//
//  Protocol for serializing and deserializing game state to/from JSON.
//

import Foundation

/// Protocol for serializing and deserializing game state to/from JSON strings.
///
/// Conforming types provide methods to convert game state objects to JSON strings
/// for persistence and to reconstruct game state objects from JSON strings.
///
/// Requirements: 12.1, 12.2, 13.1, 13.2, 14.1, 14.2
protocol GameStateSerializer {
    /// The type of game state that this serializer handles
    associatedtype StateType
    
    /// Serializes a game state object to a JSON string.
    ///
    /// - Parameter state: The game state to serialize
    /// - Returns: A JSON string representation of the state, or nil if serialization fails
    static func serialize(_ state: StateType) -> String?
    
    /// Deserializes a JSON string to a game state object.
    ///
    /// - Parameter json: The JSON string to deserialize
    /// - Returns: The reconstructed game state, or nil if deserialization fails
    static func deserialize(_ json: String) -> StateType?
}
