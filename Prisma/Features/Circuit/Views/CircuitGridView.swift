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
    /// When false the grid is purely decorative — all drag/tap input is suppressed.
    /// Pass `false` when showing the canonical solution so it cannot be edited.
    var allowsDrawing: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Computed cell size from the container width
    @State private var cellSize: CGFloat = 54

    // Tap-to-inspect: shows a floating tooltip for a tapped gate cell.
    @State private var tooltipGate: (position: GridPosition, type: GateType)? = nil
    @State private var dragStartPosition: GridPosition? = nil

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
                    pathLayer: viewModel.pathLayer,
                    gridSize: viewModel.level.size,
                    cellSize: computedCellSize,
                    gateCells: makeGateCells()
                )
                .frame(width: size, height: size)

                // LAYER 3: Tap-to-inspect tooltip
                if let tip = tooltipGate {
                    GateTooltipView(gateType: tip.type) {
                        withAnimation(.easeOut(duration: 0.15)) { tooltipGate = nil }
                    }
                    .offset(tooltipOffset(for: tip.position, cellSize: computedCellSize, in: size))
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: 12))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard allowsDrawing else { return }
                        let pos = gridPosition(for: value.location, cellSize: computedCellSize)
                        if value.translation == .zero {
                            dragStartPosition = pos
                            viewModel.dragBegan(at: pos)
                        } else {
                            // Any meaningful movement cancels the tap-to-inspect intent.
                            if hypot(value.translation.width, value.translation.height) > 4 {
                                dragStartPosition = nil
                            }
                            viewModel.dragMoved(to: pos)
                        }
                    }
                    .onEnded { value in
                        guard allowsDrawing else { return }
                        let moved = hypot(value.translation.width, value.translation.height) > 4
                        if !moved, let start = dragStartPosition,
                           case .gate(let gateType, _) = viewModel.liveGrid[start.row][start.col] {
                            // Tap on a gate — show tooltip and swallow the "drag end".
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                tooltipGate = (start, gateType)
                            }
                        } else if !moved, tooltipGate != nil {
                            withAnimation(.easeOut(duration: 0.15)) { tooltipGate = nil }
                        }
                        viewModel.dragEnded()
                        dragStartPosition = nil
                    }
            )
            .onAppear { cellSize = computedCellSize }
            .onChange(of: computedCellSize) { _, new in cellSize = new }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Tooltip positioning

    /// Places the tooltip just above/below the tapped cell, clamped to grid bounds.
    private func tooltipOffset(for position: GridPosition, cellSize: CGFloat, in boardSize: CGFloat) -> CGSize {
        let cellCenterX = (CGFloat(position.col) + 0.5) * cellSize
        let tooltipWidth: CGFloat = 220
        let tooltipHeight: CGFloat = 90
        let margin: CGFloat = 8

        var x = cellCenterX - tooltipWidth / 2
        x = max(margin, min(boardSize - tooltipWidth - margin, x))

        // Prefer placement above the cell; fall back to below if no space.
        let cellTopY = CGFloat(position.row) * cellSize
        let cellBottomY = cellTopY + cellSize
        let aboveY = cellTopY - tooltipHeight - 6
        let belowY = cellBottomY + 6
        let y = aboveY >= margin ? aboveY : belowY

        return CGSize(width: x, height: y)
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

                    // Determine active path color for waypoints (tints the crosshair)
                    let pathSignalColor: Color? = {
                        guard case .waypoint = cell else { return nil }
                        return viewModel.pathLayer[pos]?.color.swiftUIColor
                    }()

                    CircuitCellView(
                        cell: cell,
                        cellSize: cellSize,
                        isPreviewingGateOutput: isPreviewing,
                        previewOutputSignal: previewSignal,
                        activeEdges: cell.isGate ? activeEdgesForGate(at: pos) : [:],
                        activePathColor: pathSignalColor
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

    // MARK: - Gate Cell Helpers

    /// Collects all grid positions that contain gate cells, used by CircuitCanvasView
    /// to draw path stubs (stopping at the gate's visual border) instead of
    /// drawing through the gate icon.
    private func makeGateCells() -> Set<GridPosition> {
        var positions = Set<GridPosition>()
        for row in 0..<viewModel.level.size {
            for col in 0..<viewModel.level.size {
                if viewModel.liveGrid[row][col].isGate {
                    positions.insert(GridPosition(row, col))
                }
            }
        }
        return positions
    }

    /// Returns a map of `Edge → Color` for each side of a gate cell that has an
    /// active path entering or leaving it.  Used by `GateCellView` to draw the
    /// thin edge-connector lines that bridge the gap between the path stub and
    /// the gate's rounded rectangle border.
    private func activeEdgesForGate(at pos: GridPosition) -> [Edge: Color] {
        var edges: [Edge: Color] = [:]

        // Walk every active path and check if it passes through this gate.
        for (_, path) in viewModel.activePaths {
            guard let gateIdx = path.indexOfSegment(pos) else { continue }

            // Previous neighbour → edge facing that neighbour
            if gateIdx > 0 {
                let prev = path.segments[gateIdx - 1]
                if let edge = edgeFrom(pos, to: prev),
                   let signal = viewModel.pathLayer[prev] {
                    edges[edge] = signal.color.swiftUIColor
                }
            }

            // Next neighbour → edge facing that neighbour
            if gateIdx + 1 < path.segments.count {
                let next = path.segments[gateIdx + 1]
                if let edge = edgeFrom(pos, to: next),
                   let signal = viewModel.pathLayer[next] {
                    edges[edge] = signal.color.swiftUIColor
                }
            }
        }

        return edges
    }

    /// Maps the directional relationship between two adjacent positions to a SwiftUI `Edge`.
    private func edgeFrom(_ pos: GridPosition, to neighbor: GridPosition) -> Edge? {
        if neighbor.row == pos.row - 1 && neighbor.col == pos.col { return .top }
        if neighbor.row == pos.row + 1 && neighbor.col == pos.col { return .bottom }
        if neighbor.row == pos.row && neighbor.col == pos.col - 1 { return .leading }
        if neighbor.row == pos.row && neighbor.col == pos.col + 1 { return .trailing }
        return nil
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
              head.isAdjacent(to: position),
              position.row >= 0, position.row < level.size,
              position.col >= 0, position.col < level.size else { return false }
        return liveGrid[position.row][position.col].isGate
    }

    /// The hypothetical output signal if the active drag enters the gate at this position.
    func previewGateOutput(at position: GridPosition) -> PathSignal? {
        guard let color = activeDrawColor,
              let path = activePaths[color],
              let head = path.headPosition,
              position.row >= 0, position.row < level.size,
              position.col >= 0, position.col < level.size else { return nil }
        let cell = liveGrid[position.row][position.col]
        guard cell.isGate else { return nil }
        let entryDir = head.directionTo(position)
        return applyGateTransform(cell: cell, incoming: path.currentSignal, entryDirection: entryDir)
    }
}

// MARK: - Gate Tooltip

/// Floating tooltip card that describes a gate's behavior in one line.
/// Shown when the user taps a gate cell without dragging. Dismisses on tap.
private struct GateTooltipView: View {
    let gateType: GateType
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 220)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        .onTapGesture { onDismiss() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to dismiss")
    }

    private var iconName: String {
        switch gateType {
        case .notGate:     return "arrow.triangle.2.circlepath"
        case .sparkGate:   return "bolt.fill"
        case .bridge:      return "arrow.triangle.branch"
        case .synthesizer: return "arrow.triangle.merge"
        }
    }

    private var iconColor: Color {
        switch gateType {
        case .notGate:     return .orange
        case .sparkGate:   return .yellow
        case .bridge:      return .cyan
        case .synthesizer: return .purple
        }
    }

    private var title: String {
        switch gateType {
        case .notGate(let dir):
            return dir == nil ? "Inverter" : "Directional Inverter"
        case .sparkGate:   return "Spark"
        case .bridge:      return "Bridge"
        case .synthesizer: return "Synthesizer"
        }
    }

    private var detail: String {
        switch gateType {
        case .notGate(let dir):
            if dir == nil {
                return "Flips signal state (active ↔ inactive). Color unchanged."
            } else {
                return "Flips signal only when entered from the indicated direction."
            }
        case .sparkGate:
            return "Energizes an inactive signal. No effect if already active."
        case .bridge:
            return "Allows two paths of different colors to cross without mixing."
        case .synthesizer(let logic, let outputSignal):
            let op = logic == .or ? "OR" : "XOR"
            let sig = outputSignal == .active ? "active" : "inactive"
            return "Combines two inputs → mixed color, \(op) logic, output \(sig)."
        }
    }
}

// MARK: - Preview

#Preview {
    let vm = CircuitGameViewModel(levelId: 1)
    return CircuitGridView(viewModel: vm)
        .padding(24)
        .background(AppTheme.appBackground())
}
