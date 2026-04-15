//
//  CircuitCanvasView.swift
//  Prisma
//
//  Draws all active path segments as glowing neon strokes using SwiftUI Canvas.
//  Using Canvas (not per-cell views) keeps rendering smooth even on large grids.
//
//  Neon glow effect: two-pass rendering —
//    Pass 1: wide blurred stroke at 35% opacity (halo)
//    Pass 2: narrow sharp stroke at full opacity (core line)
//
//  pathLayer change: this view now reads per-segment signal color from
//  `pathLayer` (the drawing layer) rather than `liveGrid`. This produces correct
//  per-segment coloring when a gate mid-route transforms the signal color.
//

import SwiftUI

struct CircuitCanvasView: View {
    let activePaths: [NeonColor: ActivePath]
    /// Per-position signal map from the ViewModel's pathLayer.
    let pathLayer: [GridPosition: PathSignal]
    let gridSize: Int
    let cellSize: CGFloat

    var body: some View {
        Canvas { context, size in
            for (_, path) in activePaths {
                drawPath(path, in: context, size: size)
            }
        }
        .allowsHitTesting(false) // Gesture handled by the grid layer beneath.
    }

    // MARK: - Path Drawing

    private func drawPath(_ path: ActivePath, in context: GraphicsContext, size: CGSize) {
        guard path.segments.count >= 2 else {
            // Single-segment path (just the source tap) — draw start cap dot.
            if let origin = path.segments.first {
                drawStartDot(at: origin, signal: path.currentSignal, in: context)
            }
            return
        }

        // ── Pass 1 & 2: draw the full path in source color (halo + core) ──
        // We draw the full stroke in one pass first, then overlay transformed
        // segments so color changes after gates are clearly visible.
        var fullPath = Path()
        for (index, position) in path.segments.enumerated() {
            let center = cellCenter(for: position)
            if index == 0 { fullPath.move(to: center) }
            else          { fullPath.addLine(to: center) }
        }

        let baseColor = path.sourceColor.swiftUIColor

        // Halo pass
        var glowContext = context
        glowContext.opacity = 0.3
        glowContext.stroke(
            fullPath,
            with: .color(baseColor),
            style: StrokeStyle(lineWidth: cellSize * 0.55, lineCap: .round, lineJoin: .round)
        )

        // Core pass
        context.stroke(
            fullPath,
            with: .color(baseColor),
            style: StrokeStyle(lineWidth: cellSize * 0.28, lineCap: .round, lineJoin: .round)
        )

        // ── Per-segment color overlay for gate-transformed sections ──
        // Groups consecutive segments that share the same signal color into runs
        // and draws each run with its actual transformed color.
        drawPerSegmentColorOverlay(path, in: context)

        // ── Transformed-segment dashed overlay (white shimmer) ──
        drawTransformedOverlay(path, in: context)
    }

    /// Draws colored overlays on top of the base path to show gate-transformed color changes.
    private func drawPerSegmentColorOverlay(_ path: ActivePath, in context: GraphicsContext) {
        // Walk segments grouping by color. When the color changes, flush the current run.
        var runStart: Int = 0
        var runColor: Color? = nil
        var runIsTransformed = false

        func flushRun(upTo end: Int) {
            guard let color = runColor, runIsTransformed, end > runStart else { return }
            var runPath = Path()
            for i in runStart...end {
                let center = cellCenter(for: path.segments[i])
                if i == runStart { runPath.move(to: center) }
                else             { runPath.addLine(to: center) }
            }
            // Halo
            var glowCtx = context
            glowCtx.opacity = 0.35
            glowCtx.stroke(runPath, with: .color(color),
                           style: StrokeStyle(lineWidth: cellSize * 0.55, lineCap: .round, lineJoin: .round))
            // Core
            context.stroke(runPath, with: .color(color),
                           style: StrokeStyle(lineWidth: cellSize * 0.28, lineCap: .round, lineJoin: .round))
        }

        for (index, _) in path.segments.enumerated() {
            let signal = signalAt(index: index, in: path)
            let color  = signal.color.swiftUIColor

            if runColor == nil {
                runColor = color
                runIsTransformed = signal.wasTransformed
                runStart = index
            } else if color != runColor {
                flushRun(upTo: index)
                runColor = color
                runIsTransformed = signal.wasTransformed
                runStart = index
            }
        }
        // Flush last run
        flushRun(upTo: path.segments.count - 1)
    }

    /// Draws a dashed white shimmer on segments that were transformed by a gate.
    private func drawTransformedOverlay(_ path: ActivePath, in context: GraphicsContext) {
        guard path.segments.count >= 2 else { return }

        var transformedPath = Path()
        var inTransformedRun = false

        for (index, position) in path.segments.enumerated() {
            guard index < path.segments.count - 1 else { break }
            let signal     = signalAt(index: index, in: path)
            let center     = cellCenter(for: position)
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
        }

        var overlayContext = context
        overlayContext.opacity = 0.25
        overlayContext.stroke(
            transformedPath,
            with: .color(.white),
            style: StrokeStyle(
                lineWidth: cellSize * 0.14,
                lineCap: .round, lineJoin: .round,
                dash: [cellSize * 0.12, cellSize * 0.08]
            )
        )
    }

    /// Draws a dot at the source terminal position when only the start tap has been registered.
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

    /// Returns the PathSignal at an index by reading the ViewModel's pathLayer.
    /// Falls back to the path's current (final) signal for positions not yet in the layer.
    private func signalAt(index: Int, in path: ActivePath) -> PathSignal {
        let pos = path.segments[index]
        return pathLayer[pos] ?? path.currentSignal
    }
}
