//
//  CargoGrid.swift
//  Prisma
//
//  Represents the game grid state with placed pieces and validation logic.
//

import Foundation

// MARK: - Cell State

enum CargoCellState: Equatable {
    case empty
    case blocked
    case filled(pieceId: Int)   // occupied by piece with this ID
    case ghost(pieceId: Int)    // preview of a placement (not saved)

    var isEmpty: Bool { self == .empty }
    var isBlocked: Bool { self == .blocked }
    var pieceId: Int? {
        switch self {
        case .filled(let pid): return pid
        case .ghost(let pid): return pid
        default: return nil
        }
    }
}

// MARK: - Placed Piece Record

struct PlacedPiece: Equatable {
    let pieceId: Int
    let origin: CellCoord          // top-left origin of the piece on the grid
    let rotationSteps: Int
    let isFlipped: Bool
    let occupiedCells: [CellCoord] // absolute grid cells occupied
}

// MARK: - Cargo Grid

struct CargoGrid: Equatable {
    let rows: Int
    let cols: Int
    private(set) var cells: [[CargoCellState]]
    private(set) var placedPieces: [PlacedPiece] = []

    // MARK: - Init

    init(rows: Int, cols: Int, blockedCells: [CellCoord] = []) {
        self.rows = rows
        self.cols = cols
        self.cells = Array(repeating: Array(repeating: .empty, count: cols), count: rows)
        for coord in blockedCells {
            if coord.row < rows && coord.col < cols {
                cells[coord.row][coord.col] = .blocked
            }
        }
    }

    // MARK: - Queries

    subscript(row: Int, col: Int) -> CargoCellState {
        get { cells[row][col] }
    }

    func isInBounds(_ coord: CellCoord) -> Bool {
        coord.row >= 0 && coord.row < rows && coord.col >= 0 && coord.col < cols
    }

    /// Returns the absolute grid cells a piece would occupy if placed at the given origin.
    func absoluteCells(for piece: CargoPiece, at origin: CellCoord) -> [CellCoord] {
        piece.transformedCells.map { CellCoord($0.row + origin.row, $0.col + origin.col) }
    }

    /// True if the piece can legally be placed at the given origin.
    func canPlace(_ piece: CargoPiece, at origin: CellCoord) -> Bool {
        let targets = absoluteCells(for: piece, at: origin)
        return targets.allSatisfy { coord in
            isInBounds(coord) && cells[coord.row][coord.col].isEmpty
        }
    }

    /// Returns all valid origins for placing the given piece on the grid.
    func validOrigins(for piece: CargoPiece) -> [CellCoord] {
        var valid: [CellCoord] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let origin = CellCoord(r, c)
                if canPlace(piece, at: origin) {
                    valid.append(origin)
                }
            }
        }
        return valid
    }

    // MARK: - Mutations

    /// Places a piece at the origin. Returns false if placement is invalid.
    @discardableResult
    mutating func place(_ piece: CargoPiece, at origin: CellCoord) -> Bool {
        guard canPlace(piece, at: origin) else { return false }
        let targets = absoluteCells(for: piece, at: origin)
        for coord in targets {
            cells[coord.row][coord.col] = .filled(pieceId: piece.id)
        }
        placedPieces.append(PlacedPiece(
            pieceId: piece.id,
            origin: origin,
            rotationSteps: piece.rotationSteps,
            isFlipped: piece.isFlipped,
            occupiedCells: targets
        ))
        return true
    }

    /// Directly reconstructs a placement from absolute grid coordinates.
    /// Used by `CargoStateSerializer` during deserialization.
    mutating func reconstructPlacement(
        pieceId: Int,
        absoluteCells: [CellCoord],
        origin: CellCoord,
        rotationSteps: Int,
        isFlipped: Bool
    ) {
        for coord in absoluteCells {
            if isInBounds(coord) {
                cells[coord.row][coord.col] = .filled(pieceId: pieceId)
            }
        }
        placedPieces.append(PlacedPiece(
            pieceId: pieceId,
            origin: origin,
            rotationSteps: rotationSteps,
            isFlipped: isFlipped,
            occupiedCells: absoluteCells
        ))
    }

    /// Removes the last placed piece from the grid.
    @discardableResult
    mutating func undoLastPlacement() -> PlacedPiece? {
        guard let last = placedPieces.last else { return nil }
        for coord in last.occupiedCells {
            cells[coord.row][coord.col] = .empty
        }
        placedPieces.removeLast()
        return last
    }

    // MARK: - Statistics

    var filledCellCount: Int {
        cells.flatMap { $0 }.filter { if case .filled = $0 { return true }; return false }.count
    }

    var emptyCellCount: Int {
        cells.flatMap { $0 }.filter { $0.isEmpty }.count
    }

    var totalPlaceableCells: Int {
        cells.flatMap { $0 }.filter { !$0.isBlocked }.count
    }

    var fillPercentage: Double {
        totalPlaceableCells > 0 ? Double(filledCellCount) / Double(totalPlaceableCells) : 0
    }

    var isPerfectlyClear: Bool { emptyCellCount == 0 }

    // MARK: - Solution Helpers

    /// Fills the grid using pieces' absolute solution coordinates.
    ///
    /// Expects every piece to have `solutionCells` populated. Pieces missing
    /// that data are skipped — earlier versions fell back to `baseCells`,
    /// which painted every such piece stacked at (0,0). Callers that need a
    /// guaranteed complete solution should pre-check via
    /// `CargoGameViewModel.buildSolutionGrid()`.
    mutating func populateSolutionMode(with pieces: [CargoPiece]) {
        for piece in pieces {
            guard let coords = piece.solutionCells else { continue }
            for coord in coords where isInBounds(coord) {
                cells[coord.row][coord.col] = .filled(pieceId: piece.id)
            }
        }
    }
}
