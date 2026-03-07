//
//  SerializableCargoState.swift
//  Prisma
//
//  Serializable data structures for persisting Cargo game state.
//

import Foundation

/// Serializable representation of a cell coordinate
struct SerializableCellCoord: Codable {
    let row: Int
    let col: Int
}

/// Serializable representation of a placed piece
struct SerializablePlacedPiece: Codable {
    let pieceId: Int
    let baseCells: [SerializableCellCoord]  // Store the actual piece shape
    let originRow: Int
    let originCol: Int
    let rotationSteps: Int
    let isFlipped: Bool
}

/// Serializable representation of the complete Cargo grid state
struct SerializableCargoState: Codable {
    let rows: Int
    let cols: Int
    let blockedCells: [SerializableCellCoord]
    let placedPieces: [SerializablePlacedPiece]
}
