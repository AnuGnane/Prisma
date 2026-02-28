//
//  CargoPieceTray.swift
//  Prisma
//
//  Horizontal scrolling piece selector at the bottom of the Cargo game screen.
//

import SwiftUI
import UniformTypeIdentifiers

struct CargoPieceTray: View {
    let pieces: [CargoPiece]
    let placedPieceIds: Set<Int>
    let selectedIndex: Int?
    let draggingId: Int?
    let pendingId: Int?
    let onDragStart: (Int) -> Void
    let onDragCancel: () -> Void
    let onSelect: (Int) -> Void

    var body: some View {
        // Piece tray - pure scrollable list now
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(pieces) { piece in
                    let idx = pieces.firstIndex(where: { $0.id == piece.id }) ?? 0
                    let isDragging = piece.id == draggingId
                    Button {
                        if !placedPieceIds.contains(piece.id) {
                            onSelect(idx)
                        }
                    } label: {
                        PieceThumbnail(
                            piece: piece,
                            isSelected: selectedIndex == idx,
                            isPlaced: placedPieceIds.contains(piece.id) || piece.id == draggingId || piece.id == pendingId
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onDrag {
                        if !placedPieceIds.contains(piece.id) {
                            onSelect(idx) // Select it when drag starts too
                            onDragStart(piece.id)
                        }
                        return NSItemProvider(object: String(piece.id) as NSString)
                        PieceThumbnail(piece: piece, isSelected: true, isPlaced: false)
                            .onDisappear {
                                // If the preview disappears (drop ended organically or OS aborted it),
                                // calling cancelDrag gracefully handles any stuck dragging state.
                                onDragCancel()
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .frame(height: 80) // Fixed height to prevent squeezing
    }
}

// MARK: - Piece Thumbnail

struct PieceThumbnail: View {
    let piece: CargoPiece
    let isSelected: Bool
    let isPlaced: Bool

    var body: some View {
        let cells = piece.transformedCells
        let maxRow = (cells.map(\.row).max() ?? 0) + 1
        let maxCol = (cells.map(\.col).max() ?? 0) + 1
        
        let previewSize: CGFloat = 56
        let padding: CGFloat = 12
        let availableSpace = previewSize - padding
        
        // Calculate dynamic cell size so it always fits
        let cellSpacing: CGFloat = 1.5
        let maxDimension = CGFloat(max(maxRow, maxCol))
        let cellSize: CGFloat = (availableSpace - (maxDimension - 1) * cellSpacing) / maxDimension

        ZStack {
            // Background card
            RoundedRectangle(cornerRadius: 12)
                .fill(isPlaced
                    ? Color.primary.opacity(0.04)
                    : isSelected
                        ? piece.color.opacity(0.25)
                        : Color.primary.opacity(0.08)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isSelected ? piece.color : Color.primary.opacity(0.1),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

            let totalW = CGFloat(maxCol) * cellSize + CGFloat(maxCol - 1) * cellSpacing
            let totalH = CGFloat(maxRow) * cellSize + CGFloat(maxRow - 1) * cellSpacing

            ForEach(cells, id: \.self) { coord in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color.opacity(isSelected ? 0.9 : 0.65))
                    .frame(width: cellSize, height: cellSize)
                    .offset(
                        x: (CGFloat(coord.col) * (cellSize + cellSpacing)) - totalW / 2 + cellSize / 2,
                        y: (CGFloat(coord.row) * (cellSize + cellSpacing)) - totalH / 2 + cellSize / 2
                    )
            }
        }
        .frame(width: previewSize, height: previewSize)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        .opacity(isPlaced ? 0.45 : 1.0)
    }
}
