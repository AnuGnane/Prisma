//
//  CargoPiece.swift
//  Prisma
//
//  Represents a single puzzle piece with cells, rotation, and flip state.
//

import Foundation
import SwiftUI

// MARK: - Cell Coordinate

struct CellCoord: Hashable, Codable {
    let row: Int
    let col: Int

    init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        row = try container.decode(Int.self)
        col = try container.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(row)
        try container.encode(col)
    }
}

// MARK: - Cargo Piece

struct CargoPiece: Identifiable, Codable, Equatable {
    let id: Int
    /// Base cells in relative coordinates (row, col from origin 0,0)
    let baseCells: [CellCoord]

    // MARK: Transformation State

    var rotationSteps: Int = 0   // 0, 1, 2, 3 (each step = 90° clockwise)
    var isFlipped: Bool = false
    
    /// Absolute grid coordinates where this piece sits in the solution.
    /// Set by `CargoPuzzleGenerator`; nil for JSON-loaded puzzle pieces.
    var solutionCells: [CellCoord]? = nil

    // MARK: - Computed Transformed Cells

    /// Currently transformed cells, normalized to start at (0,0)
    var transformedCells: [CellCoord] {
        var cells = baseCells
        if isFlipped {
            cells = cells.map { CellCoord($0.row, -$0.col) }
        }
        for _ in 0..<rotationSteps {
            cells = cells.map { CellCoord($0.col, -$0.row) }
        }
        return normalized(cells)
    }

    /// Bounding box of transformed cells
    var bounds: (rows: Int, cols: Int) {
        let cells = transformedCells
        let maxR = cells.map(\.row).max() ?? 0
        let maxC = cells.map(\.col).max() ?? 0
        return (maxR + 1, maxC + 1)
    }

    // MARK: - Mutation (value type helpers)

    func rotated() -> CargoPiece {
        var copy = self
        copy.rotationSteps = (rotationSteps + 1) % 4
        return copy
    }

    func flipped() -> CargoPiece {
        var copy = self
        copy.isFlipped.toggle()
        return copy
    }

    // MARK: - Normalization

    private func normalized(_ cells: [CellCoord]) -> [CellCoord] {
        guard !cells.isEmpty else { return [] }
        let minR = cells.map(\.row).min()!
        let minC = cells.map(\.col).min()!
        return cells.map { CellCoord($0.row - minR, $0.col - minC) }
            .sorted { $0.row == $1.row ? $0.col < $1.col : $0.row < $1.row }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case cells
        /// Canonical absolute grid coords for this piece in the solved puzzle.
        /// Produced offline by `scratch/solve_cargo.py` for every level in
        /// `cargo_puzzles.json`, so "Show Solution" can reconstruct a true
        /// 100%-fill layout instead of the player's partial state.
        case solution
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        baseCells = try container.decode([CellCoord].self, forKey: .cells)
        solutionCells = try container.decodeIfPresent([CellCoord].self, forKey: .solution)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(baseCells, forKey: .cells)
        try container.encodeIfPresent(solutionCells, forKey: .solution)
    }
}

// MARK: - Piece Colours

extension CargoPiece {
    static let pieceColors: [Color] = [
        Color(red: 0.24, green: 0.86, blue: 0.52),  // emerald green
        Color(red: 0.29, green: 0.56, blue: 0.89),  // cerulean blue
        Color(red: 1.00, green: 0.42, blue: 0.42),  // coral red
        Color(red: 1.00, green: 0.85, blue: 0.24),  // amber
        Color(red: 0.78, green: 0.48, blue: 1.00),  // lavender
        AppTheme.cargo,  // tangerine
        Color(red: 0.27, green: 0.85, blue: 0.78),  // teal
        Color(red: 1.00, green: 0.41, blue: 0.71),  // pink
    ]

    var color: Color {
        CargoPiece.pieceColors[(id - 1) % CargoPiece.pieceColors.count]
    }
}
