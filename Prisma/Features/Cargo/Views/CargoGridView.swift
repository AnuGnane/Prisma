//
//  CargoGridView.swift
//  Prisma
//
//  Renders the Cargo game grid. Each cell can be empty, blocked, filled (by a piece),
//  or shown as a ghost preview when the player is hovering a piece over the grid.
//

import SwiftUI
import UniformTypeIdentifiers

struct CargoGridView: View {
    let grid: CargoGrid
    let ghostCells: [CellCoord]
    let ghostIsValid: Bool
    
    // Support picking up a pending piece
    let pendingCells: [CellCoord]
    let pendingPieceId: Int?
    var onDragPending: (() -> Void)? = nil
    
    var onTapCell: ((CellCoord) -> Void)? = nil
    var onHoverGrid: (CellCoord?) -> Void
    var onDropGrid: () -> Void
    
    @State private var animatingCells: Set<CellCoord> = []
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Dynamic cell size — fits grid within available width
    private let minCellSize: CGFloat = 36
    private let maxCellSize: CGFloat = 60
    private let cellSpacing: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let cellSize = computeCellSize(geo.size.width)
            let totalW = CGFloat(grid.cols) * cellSize + CGFloat(grid.cols - 1) * cellSpacing
            let totalH = CGFloat(grid.rows) * cellSize + CGFloat(grid.rows - 1) * cellSpacing

            VStack(spacing: cellSpacing) {
                ForEach(0..<grid.rows, id: \.self) { row in
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<grid.cols, id: \.self) { col in
                            let coord = CellCoord(row, col)
                            
                            // If this cell is part of the pending piece, make it draggable
                            let isPending = pendingCells.contains(coord)
                            
                            cellView(for: coord, size: cellSize)
                                .onTapGesture { onTapCell?(coord) }
                                .onDrag {
                                    if isPending {
                                        onDragPending?()
                                        return NSItemProvider(object: String(pendingPieceId ?? 0) as NSString)
                                    }
                                    return NSItemProvider()
                                } preview: {
                                    if isPending, let pId = pendingPieceId {
                                        PieceThumbnail(
                                            piece: CargoPiece(id: pId, baseCells: pendingCells),
                                            isSelected: false,
                                            isPlaced: false
                                        )
                                    } else {
                                        EmptyView()
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Grid cell row \(row + 1), column \(col + 1)")
                                .accessibilityValue(stateDescription(for: grid[row, col]))
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                }
            }
            .frame(width: totalW, height: totalH)
            .background(Color.clear) // ensure hit area
            .onDrop(
                of: [.text],
                delegate: CargoDropDelegate(
                    cellSize: cellSize,
                    cellSpacing: cellSpacing,
                    onHover: onHoverGrid,
                    onDrop: onDropGrid
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .onChange(of: grid) { oldGrid, newGrid in
                // Detect newly placed pieces to trigger the pop animation
                guard !reduceMotion else { return }
                var newPlacements: Set<CellCoord> = []
                for r in 0..<newGrid.rows {
                    for c in 0..<newGrid.cols {
                        if case .filled = newGrid[r, c] {
                            if case .filled = oldGrid[r, c] {
                                // already filled
                            } else {
                                newPlacements.insert(CellCoord(r, c))
                            }
                        }
                    }
                }
                if !newPlacements.isEmpty {
                    animatingCells = newPlacements
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        animatingCells.removeAll()
                    }
                }
            }
        }
    }

    // MARK: - Cell View

    @ViewBuilder
    private func cellView(for coord: CellCoord, size: CGFloat) -> some View {
        let state = grid[coord.row, coord.col]
        let isGhost = ghostCells.contains(coord)

        RoundedRectangle(cornerRadius: size * 0.18)
            .fill(cellFill(state: state, isGhost: isGhost))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.18)
                    .strokeBorder(cellBorder(state: state, isGhost: isGhost), lineWidth: 1.5)
            )
            .frame(width: size, height: size)
            .scaleEffect(isGhost ? (ghostIsValid ? 0.96 : 0.88) : (animatingCells.contains(coord) ? 1.15 : 1.0))
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7), value: isGhost)
    }

    // MARK: - Colours

    private func cellFill(state: CargoCellState, isGhost: Bool) -> Color {
        if isGhost {
            return ghostIsValid
                ? (selectedPieceColor?.opacity(0.5) ?? Color.primary.opacity(0.3))
                : Color.red.opacity(0.3)
        }
        switch state {
        case .empty:
            return AppTheme.cellFill
        case .blocked:
            return Color.primary.opacity(0.2)
        case .filled(let pid):
            return colorForPiece(pid).opacity(0.85)
        case .ghost(let pid):
            return colorForPiece(pid).opacity(0.4)
        }
    }

    private func cellBorder(state: CargoCellState, isGhost: Bool) -> Color {
        if isGhost {
            return ghostIsValid
                ? (selectedPieceColor ?? Color.primary).opacity(0.6)
                : Color.red.opacity(0.5)
        }
        switch state {
        case .empty:    return AppTheme.cellBorder
        case .blocked:  return Color.primary.opacity(0.3)
        case .filled(let pid): return colorForPiece(pid).opacity(0.6)
        case .ghost(let pid):  return colorForPiece(pid).opacity(0.5)
        }
    }

    private func colorForPiece(_ pieceId: Int) -> Color {
        CargoPiece.pieceColors[(pieceId - 1) % CargoPiece.pieceColors.count]
    }

    private var selectedPieceColor: Color? { nil }

    // MARK: - Size Computation

    private func computeCellSize(_ availableWidth: CGFloat) -> CGFloat {
        let usableWidth = availableWidth - 32
        let rawSize = (usableWidth - CGFloat(grid.cols - 1) * cellSpacing) / CGFloat(grid.cols)
        return min(max(rawSize, minCellSize), maxCellSize)
    }

    private func stateDescription(for state: CargoCellState) -> String {
        switch state {
        case .empty: return "Empty"
        case .blocked: return "Blocked"
        case .filled(let pid): return "Filled with piece \(pid)"
        case .ghost: return "Previewing piece"
        }
    }
}

// MARK: - Drop Delegate

struct CargoDropDelegate: DropDelegate {
    let cellSize: CGFloat
    let cellSpacing: CGFloat
    let onHover: (CellCoord?) -> Void
    let onDrop: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let loc = info.location
        let totalCellSize = cellSize + cellSpacing
        
        let col = Int(loc.x / totalCellSize)
        let row = Int(loc.y / totalCellSize)
        
        // Let the ViewModel bounds check the origin
        onHover(CellCoord(row, col))
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        let loc = info.location
        let totalCellSize = cellSize + cellSpacing
        let col = Int(loc.x / totalCellSize)
        let row = Int(loc.y / totalCellSize)
        
        // Explicitly set the location just before drop to prevent disappearing
        // if dropExited fired slightly early.
        onHover(CellCoord(row, col))
        onDrop()
        return true
    }
    
    func dropExited(info: DropInfo) {
        // Don't eagerly clear it during a valid move to prevent disappearance
        // onDropGrid handles clearing drag state anyway.
    }
}
