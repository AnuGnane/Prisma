//
//  CircuitCanvasView.swift
//  Prisma
//
//  Draws all active path segments as glowing neon strokes using SwiftUI Canvas.
//  Using Canvas (not per-cell views) keeps rendering smooth even on large grids.
//
//  Neon glow effect: two pass rendering —
//    Pass 1: wide blurred stroke at 30% opacity (halo)
//    Pass 2: narrow sharp stroke at full opacity (core line)
//

import SwiftUI

struct CircuitCanvasView: View {
    let activePaths: [NeonColor: ActivePath]
    let liveGrid: [[CellState]]
    let gridSize: Int
    let cellSize: CGFloat

    var body: some View {
        Canvas { context, size in
            for (_, path) in activePaths {
                drawPath(path, in: context, size: size)
            }
        }
        .allowsHitTesting(false) // Gesture handled by the grid layer beneath
    }

    // MARK: - Path Drawing

    private func drawPath(_ path: ActivePath, in context: GraphicsContext, size: CGSize) {
        guard path.segments.count >= 2 else {
            // Single-segment path (just the source tap) — draw start cap dot
            if let origin = path.segments.first {
                drawStartDot(at: origin, signal: path.currentSignal, in: context)
            }
            return
        }

        // Build a continuous UIBezierPath-style SwiftUI Path
        var swiftUIPath = Path()
        var prevCenter: CGPoint? = nil

        for (index, position) in path.segments.enumerated() {
            let center = cellCenter(for: position)
            let signal: PathSignal = signalAt(index: index, in: path)

            if index == 0 {
                swiftUIPath.move(to: center)
                prevCenter = center
            } else {
                swiftUIPath.addLine(to: center)
                prevCenter = center
            }
        }

        // Draw glow pass (wide, translucent)
        let baseColor = path.currentSignal.color.swiftUIColor
        var glowStroke = context
        glowStroke.opacity = 0.35
        glowStroke.stroke(
            swiftUIPath,
            with: .color(baseColor),
            style: StrokeStyle(lineWidth: cellSize * 0.55, lineCap: .round, lineJoin: .round)
        )

        // Draw core pass (narrow, opaque)
        context.stroke(
            swiftUIPath,
            with: .color(baseColor),
            style: StrokeStyle(lineWidth: cellSize * 0.28, lineCap: .round, lineJoin: .round)
        )

        // Draw transformed segment overlay (slightly lighter tint to show transform happened)
        drawTransformedOverlay(path: path, in: context)
    }

    /// Draws a subtle white overlay on segments that were transformed by a gate.
    private func drawTransformedOverlay(path: ActivePath, in context: GraphicsContext) {
        guard path.segments.count >= 2 else { return }

        var transformedPath = Path()
        var inTransformedRun = false
        var lastCenter: CGPoint? = nil

        for (index, position) in path.segments.enumerated() {
            guard index < path.segments.count - 1 else { break }
            let cell = liveGrid[position.row][position.col]
            let signal = signalAt(index: index, in: path)
            let center = cellCenter(for: position)
            let nextCenter = cellCenter(for: path.segments[index + 1])

            if signal.wasTransformed {
                if !inTransformedRun {
                    transformedPath.move(to: center)
                    inTransformedRun = true
                }
                transformedPath.addLine(to: nextCenter)
            } else {
                inTransformedRun = false
            }
            lastCenter = center
        }

        var overlayContext = context
        overlayContext.opacity = 0.25
        overlayContext.stroke(
            transformedPath,
            with: .color(.white),
            style: StrokeStyle(lineWidth: cellSize * 0.14, lineCap: .round, lineJoin: .round, dash: [cellSize * 0.12, cellSize * 0.08])
        )
    }

    /// Draws the pulsing dot at the path origin (source terminal position).
    private func drawStartDot(at position: GridPosition, signal: PathSignal, in context: GraphicsContext) {
        let center = cellCenter(for: position)
        let radius = cellSize * 0.16
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        var dotContext = context
        dotContext.opacity = 0.7
        dotContext.fill(Path(ellipseIn: rect), with: .color(signal.color.swiftUIColor))
    }

    // MARK: - Helpers

    private func cellCenter(for position: GridPosition) -> CGPoint {
        CGPoint(
            x: (CGFloat(position.col) + 0.5) * cellSize,
            y: (CGFloat(position.row) + 0.5) * cellSize
        )
    }

    /// Returns the PathSignal at an index in the path by reading from the live grid.
    /// Falls back to path.currentSignal for the last segment.
    private func signalAt(index: Int, in path: ActivePath) -> PathSignal {
        let pos = path.segments[index]
        if case .path(let signal, _) = liveGrid[pos.row][pos.col] {
            return signal
        }
        return path.currentSignal
    }
}
