//
//  ShiftGridView.swift
//  Prisma
//
//  Interactive 8×8 grid with scroll-wheel drag, haptics, and row/column glow.
//

import SwiftUI

struct ShiftGridView: View {
    @Binding var grid: ShiftGrid
    let highlightedCells: Set<Int>
    let hintCells: Set<Int>
    let interactive: Bool
    let onMove: (ShiftMove) -> Void

    @State private var rowOffsets: [CGFloat] = Array(repeating: 0, count: ShiftGrid.size)
    @State private var colOffsets: [CGFloat] = Array(repeating: 0, count: ShiftGrid.size)
    @State private var activeDrag: ActiveDrag? = nil
    @State private var totalDragTranslation: CGFloat = 0
    @State private var appliedSteps: Int = 0
    @State private var cellPops: Set<Int> = []
    @State private var shimmerCells: Set<Int> = []

    private let spacing: CGFloat = 3

    enum ActiveDrag: Equatable {
        case row(Int)
        case column(Int)
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let inset: CGFloat = 6 // Internal padding to prevent clipping
            let usable = side - inset * 2
            let totalSpacing = spacing * CGFloat(ShiftGrid.size - 1)
            let cellSize = (usable - totalSpacing) / CGFloat(ShiftGrid.size)
            let step = cellSize + spacing

            ZStack {
                // Grid background
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.04), lineWidth: 1)
                    )

                // Active row/column glow line
                if let drag = activeDrag {
                    glowLine(for: drag, step: step, usable: usable, inset: inset)
                }

                // Grid cells
                ForEach(0..<ShiftGrid.size, id: \.self) { row in
                    ForEach(0..<ShiftGrid.size, id: \.self) { col in
                        let idx = row * ShiftGrid.size + col
                        let highlighted = highlightedCells.contains(idx)
                        let popping = cellPops.contains(idx)
                        let shimmering = shimmerCells.contains(idx)

                        GridCellView(
                            letter: grid[row, col],
                            isHighlighted: highlighted,
                            isHintCell: hintCells.contains(idx)
                        )
                        .frame(width: cellSize, height: cellSize)
                        .scaleEffect(popping ? 1.2 : shimmering ? 1.08 : highlighted ? 1.02 : 1.0)
                        .brightness(shimmering ? 0.3 : 0)
                        .offset(cellOffset(row: row, col: col))
                        .zIndex(isActive(row: row, col: col) ? 2 : highlighted ? 1 : 0)
                        .position(
                            x: inset + CGFloat(col) * step + cellSize / 2,
                            y: inset + CGFloat(row) * step + cellSize / 2
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: popping)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: shimmering)
                        .animation(.interpolatingSpring(stiffness: 200, damping: 18), value: highlighted)
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
            .gesture(interactive ? dragGesture(step: step) : nil)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: highlightedCells) { oldVal, newVal in
            let fresh = newVal.subtracting(oldVal)
            if !fresh.isEmpty {
                // Word found — celebrate with shimmer + pop
                Haptics.playSuccess()
                shimmerCells = fresh
                cellPops = fresh

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation { cellPops = [] }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.4)) { shimmerCells = [] }
                }
            }
        }
    }

    // MARK: - Glow Line

    @ViewBuilder
    private func glowLine(for drag: ActiveDrag, step: CGFloat, usable: CGFloat, inset: CGFloat) -> some View {
        let side = usable + inset * 2
        switch drag {
        case .row(let r):
            let y = inset + CGFloat(r) * step + step / 2
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.2), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: side, height: step)
                .position(x: side / 2, y: y)
                .allowsHitTesting(false)

        case .column(let c):
            let x = inset + CGFloat(c) * step + step / 2
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.2), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: step, height: side)
                .position(x: x, y: side / 2)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Drag Gesture

    private func dragGesture(step: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in onDrag(value, step: step) }
            .onEnded { _ in onDragEnd(step: step) }
    }

    private func onDrag(_ value: DragGesture.Value, step: CGFloat) {
        let startRow = clamp(Int(value.startLocation.y / step))
        let startCol = clamp(Int(value.startLocation.x / step))

        if activeDrag == nil {
            let isH = abs(value.translation.width) > abs(value.translation.height)
            activeDrag = isH ? .row(startRow) : .column(startCol)
            totalDragTranslation = 0
            appliedSteps = 0
        }

        switch activeDrag {
        case .row(let r):
            let raw = value.translation.width
            let stepsNow = Int(raw / step)
            let delta = stepsNow - appliedSteps

            if delta != 0 {
                for _ in 0..<abs(delta) {
                    let move: ShiftMove = delta > 0 ? .rowRight(r) : .rowLeft(r)
                    onMove(move)
                }
                appliedSteps = stepsNow
                Haptics.playLightImpact()
            }

            rowOffsets[r] = raw - CGFloat(stepsNow) * step

        case .column(let c):
            let raw = value.translation.height
            let stepsNow = Int(raw / step)
            let delta = stepsNow - appliedSteps

            if delta != 0 {
                for _ in 0..<abs(delta) {
                    let move: ShiftMove = delta > 0 ? .columnDown(c) : .columnUp(c)
                    onMove(move)
                }
                appliedSteps = stepsNow
                Haptics.playLightImpact()
            }

            colOffsets[c] = raw - CGFloat(stepsNow) * step

        case .none: break
        }
    }

    private func onDragEnd(step: CGFloat) {
        switch activeDrag {
        case .row(let r):
            let fraction = rowOffsets[r]
            if abs(fraction) > step * 0.4 {
                let move: ShiftMove = fraction > 0 ? .rowRight(r) : .rowLeft(r)
                onMove(move)
                Haptics.playLightImpact()
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { rowOffsets[r] = 0 }

        case .column(let c):
            let fraction = colOffsets[c]
            if abs(fraction) > step * 0.4 {
                let move: ShiftMove = fraction > 0 ? .columnDown(c) : .columnUp(c)
                onMove(move)
                Haptics.playLightImpact()
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { colOffsets[c] = 0 }

        case .none: break
        }

        withAnimation(.easeOut(duration: 0.15)) { activeDrag = nil }
        totalDragTranslation = 0
        appliedSteps = 0
    }

    // MARK: - Helpers

    private func cellOffset(row: Int, col: Int) -> CGSize {
        CGSize(width: rowOffsets[row], height: colOffsets[col])
    }

    private func isActive(row: Int, col: Int) -> Bool {
        switch activeDrag {
        case .row(let r): return r == row
        case .column(let c): return c == col
        case .none: return false
        }
    }

    private func clamp(_ i: Int) -> Int { min(max(i, 0), ShiftGrid.size - 1) }
}
