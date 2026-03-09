//
//  CargoStateSerializer.swift
//  Prisma
//
//  Serializer for converting CargoGrid state to/from JSON.
//

import Foundation

/// Serializer for CargoGrid state persistence.
///
/// Converts CargoGrid objects to JSON strings for storage in GameResult and
/// reconstructs CargoGrid objects from JSON strings for display in history views.
///
/// Requirements: 1.1, 1.2, 1.3, 1.4, 12.1, 12.2, 12.3, 12.4, 12.5
enum CargoStateSerializer: GameStateSerializer {
    typealias StateType = CargoGrid
    
    /// Serializes a CargoGrid to a JSON string.
    ///
    /// Extracts grid dimensions, blocked cells, and placed pieces with their
    /// transformation data (rotation, flip, origin) and encodes to JSON.
    ///
    /// - Parameter state: The CargoGrid to serialize
    /// - Returns: JSON string representation, or nil if encoding fails
    static func serialize(_ state: CargoGrid) -> String? {
        // Extract blocked cells from the grid
        let blockedCells = extractBlockedCells(from: state)
        
        // Map placed pieces to serializable format
        let serializedPieces = state.placedPieces.map { placedPiece in
            // Get the original piece to extract baseCells
            // We need to reconstruct the piece from the grid's placed piece data
            let baseCells = extractBaseCells(from: placedPiece)
            
            return SerializablePlacedPiece(
                pieceId: placedPiece.pieceId,
                baseCells: baseCells.map { SerializableCellCoord(row: $0.row, col: $0.col) },
                originRow: placedPiece.origin.row,
                originCol: placedPiece.origin.col,
                rotationSteps: placedPiece.rotationSteps,
                isFlipped: placedPiece.isFlipped
            )
        }
        
        // Create serializable state
        let serializableState = SerializableCargoState(
            rows: state.rows,
            cols: state.cols,
            blockedCells: blockedCells,
            placedPieces: serializedPieces
        )
        
        // Encode to JSON
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(serializableState)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("❌ CargoStateSerializer: Failed to convert data to UTF-8 string")
                return nil
            }
            return jsonString
        } catch {
            print("❌ CargoStateSerializer: Failed to encode grid - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Deserializes a JSON string to a CargoGrid.
    ///
    /// Reconstructs the grid with dimensions and blocked cells, then replays
    /// piece placements by loading pieces from CargoPuzzleLoader and applying
    /// transformations.
    ///
    /// - Parameter json: JSON string to deserialize
    /// - Returns: Reconstructed CargoGrid, or nil if deserialization fails
    static func deserialize(_ json: String) -> CargoGrid? {
        return deserialize(json, originalPieces: nil)
    }

    static func deserialize(_ json: String, originalPieces: [CargoPiece]?) -> CargoGrid? {
        // Convert string to data
        guard let data = json.data(using: .utf8) else {
            print("❌ CargoStateSerializer: Invalid UTF-8 encoding")
            return nil
        }
        
        // Decode JSON
        let decoder = JSONDecoder()
        let state: SerializableCargoState
        do {
            state = try decoder.decode(SerializableCargoState.self, from: data)
        } catch {
            print("❌ CargoStateSerializer: Failed to decode JSON - \(error.localizedDescription)")
            return nil
        }
        
        // Reconstruct grid with blocked cells
        let blockedCoords = state.blockedCells.map { CellCoord($0.row, $0.col) }
        var grid = CargoGrid(rows: state.rows, cols: state.cols, blockedCells: blockedCoords)
        
        // Reconstruct placed pieces
        for placedPiece in state.placedPieces {
            // Find the original piece to retain correct baseCells and offset
            var piece: CargoPiece
            if let originalPiece = originalPieces?.first(where: { $0.id == placedPiece.pieceId }) {
                piece = originalPiece
            } else {
                // Fallback: Reconstruct the piece from saved baseCells (may have origin shift issues)
                let baseCells = placedPiece.baseCells.map { CellCoord($0.row, $0.col) }
                piece = CargoPiece(id: placedPiece.pieceId, baseCells: baseCells)
            }

            piece.rotationSteps = placedPiece.rotationSteps
            piece.isFlipped = placedPiece.isFlipped
            
            let origin = CellCoord(placedPiece.originRow, placedPiece.originCol)
            if !grid.place(piece, at: origin) {
                print("⚠️ CargoStateSerializer: Failed to place piece \(placedPiece.pieceId) at (\(origin.row), \(origin.col))")
            }
        }
        
        return grid
    }
    
    // MARK: - Private Helpers
    
    /// Extracts blocked cells from the grid by scanning all cells.
    private static func extractBlockedCells(from grid: CargoGrid) -> [SerializableCellCoord] {
        var blocked: [SerializableCellCoord] = []
        for row in 0..<grid.rows {
            for col in 0..<grid.cols {
                if grid[row, col].isBlocked {
                    blocked.append(SerializableCellCoord(row: row, col: col))
                }
            }
        }
        return blocked
    }
    
    /// Extracts the base cells from a placed piece by reverse-transforming the occupied cells.
    ///
    /// Takes the occupied cells (absolute grid coordinates) and converts them back to
    /// the piece's base cells (relative coordinates starting at 0,0) by:
    /// 1. Converting to relative coordinates (subtract origin)
    /// 2. Reversing rotation transformations
    /// 3. Reversing flip transformation
    private static func extractBaseCells(from placedPiece: PlacedPiece) -> [CellCoord] {
        // Convert occupied cells to relative coordinates
        var cells = placedPiece.occupiedCells.map { coord in
            CellCoord(coord.row - placedPiece.origin.row, coord.col - placedPiece.origin.col)
        }
        
        // Reverse rotation (rotate counter-clockwise by rotationSteps)
        for _ in 0..<placedPiece.rotationSteps {
            cells = cells.map { CellCoord(-$0.col, $0.row) }
        }
        
        // Reverse flip
        if placedPiece.isFlipped {
            cells = cells.map { CellCoord($0.row, -$0.col) }
        }
        
        // Normalize to start at (0,0)
        guard !cells.isEmpty else { return [] }
        let minR = cells.map(\.row).min()!
        let minC = cells.map(\.col).min()!
        return cells.map { CellCoord($0.row - minR, $0.col - minC) }
            .sorted { $0.row == $1.row ? $0.col < $1.col : $0.row < $1.row }
    }
}
