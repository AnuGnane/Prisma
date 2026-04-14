//
//  CircuitGridView.swift
//  Prisma
//
//  Master grid view: LazyVGrid cell layer + Canvas neon path overlay.
//  A single DragGesture(minimumDistance: 0) handles all drawing input.
//  The gesture converts CGPoint → GridPosition using the measured cell size.
//

import SwiftUI

struct CircuitGridView: View {
    @Bindable var viewModel: CircuitGameViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Computed cell size from the container width
    @State private var cellSize: CGFloat = 54

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let computedCellSize = size / CGFloat(viewModel.level.size)

            ZStack(alignment: .topLeading) {
                // LAYER 1: Cell backgrounds and entities (terminals, gates, waypoints)
                cellGrid(cellSize: computedCellSize)

                // LAYER 2: Neon path canvas overlay
                CircuitCanvasView(
                    activePaths: viewModel.activePaths,
                    liveGrid: viewModel.liveGrid,
                    gridSize: viewModel.level.size,
                    cellSize: computedCellSize
                )
                .frame(width: size, height: size)
            }
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: 12))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let pos = gridPosition(for: value.location, cellSize: computedCellSize)
                        if value.translation == .zero {
                            // Drag started
                            viewModel.dragBegan(at: pos)
                        } else {
                            viewModel.dragMoved(to: pos)
                        }
                    }
                    .onEnded { _ in
                        viewModel.dragEnded()
                    }
            )
            .onAppear { cellSize = computedCellSize }
            .onChange(of: computedCellSize) { _, new in cellSize = new }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Cell Grid

    private func cellGrid(cellSize: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: viewModel.level.size)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<viewModel.level.size, id: \.self) { row in
                ForEach(0..<viewModel.level.size, id: \.self) { col in
                    let pos = GridPosition(row, col)
                    let cell = viewModel.liveGrid[row][col]
                    let isPreviewing = viewModel.isPreviewingGate(at: pos)
                    let previewSignal = isPreviewing ? viewModel.previewGateOutput(at: pos) : nil

                    CircuitCellView(
                        cell: cell,
                        cellSize: cellSize,
                        isPreviewingGateOutput: isPreviewing,
                        previewOutputSignal: previewSignal
                    )
                    .frame(width: cellSize, height: cellSize)
                    .background(cellBackground(for: cell, cellSize: cellSize))
                }
            }
        }
    }

    // MARK: - Cell Background

    private func cellBackground(for cell: CellState, cellSize: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color.primary.opacity(0.025))
            .overlay(
                Rectangle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
    }

    // MARK: - Coordinate Mapping

    private func gridPosition(for point: CGPoint, cellSize: CGFloat) -> GridPosition {
        let row = max(0, min(viewModel.level.size - 1, Int(point.y / cellSize)))
        let col = max(0, min(viewModel.level.size - 1, Int(point.x / cellSize)))
        return GridPosition(row, col)
    }
}

// MARK: - ViewModel: Gate Preview Helpers

extension CircuitGameViewModel {
    /// True when the currently active drag is adjacent to a gate at this position,
    /// so the gate should display its exit-color preview.
    func isPreviewingGate(at position: GridPosition) -> Bool {
        guard let color = activeDrawColor,
              let path = activePaths[color],
              let head = path.headPosition,
              head.isAdjacent(to: position) else { return false }
        return liveGrid[position.row][position.col].isGate
    }

    /// The hypothetical output signal if the active drag enters the gate at this position.
    func previewGateOutput(at position: GridPosition) -> PathSignal? {
        guard let color = activeDrawColor,
              let path = activePaths[color],
              let head = path.headPosition else { return nil }
        let cell = liveGrid[position.row][position.col]
        guard cell.isGate else { return nil }
        let entryDir = head.directionTo(position)
        return applyGateTransform(cell: cell, incoming: path.currentSignal, entryDirection: entryDir)
    }
}

// MARK: - Preview

#Preview {
    let vm = CircuitGameViewModel(levelId: 1)
    return CircuitGridView(viewModel: vm)
        .padding(24)
        .background(AppTheme.appBackground())
}
