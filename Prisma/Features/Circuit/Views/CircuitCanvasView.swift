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

        // Group the path into runs of (color, signal) pairs so every run can be
        // styled for its current signal state (active = solid glow, inactive =
        // solid + dimmed). Inactive runs "wake up" (brighten) once the path
        // has reached its matching target — so a path intentionally wired to
        // an inactive target renders at full brightness on completion.
        let runs = buildSegmentRuns(for: path)
        for run in runs {
            drawRun(run, path: path, in: context)
        }

        // ── Transformed-segment dashed overlay (white shimmer) ──
        // Retained for the subtle "something changed here" cue at gate cells.
        drawTransformedOverlay(path, in: context)
    }

    // MARK: - Run Construction

    /// A contiguous stretch of segments that share the same color AND signal state.
    private struct SegmentRun {
        let startIndex: Int
        let endIndex: Int
        let color: NeonColor
        let signal: SignalState
        let wasTransformed: Bool
    }

    private func buildSegmentRuns(for path: ActivePath) -> [SegmentRun] {
        var runs: [SegmentRun] = []
        guard !path.segments.isEmpty else { return runs }

        var runStart = 0
        var currentSignal = signalAt(index: 0, in: path)

        for i in 1..<path.segments.count {
            let sig = signalAt(index: i, in: path)
            if sig.color != currentSignal.color || sig.signal != currentSignal.signal {
                runs.append(SegmentRun(
                    startIndex: runStart,
                    endIndex: i - 1,
                    color: currentSignal.color,
                    signal: currentSignal.signal,
                    wasTransformed: currentSignal.wasTransformed
                ))
                runStart = i - 1  // overlap by one segment so lines connect
                currentSignal = sig
            }
        }
        runs.append(SegmentRun(
            startIndex: runStart,
            endIndex: path.segments.count - 1,
            color: currentSignal.color,
            signal: currentSignal.signal,
            wasTransformed: currentSignal.wasTransformed
        ))
        return runs
    }

    private func drawRun(_ run: SegmentRun, path: ActivePath, in context: GraphicsContext) {
        guard run.endIndex > run.startIndex else { return }

        var runPath = Path()
        for i in run.startIndex...run.endIndex {
            let center = cellCenter(for: path.segments[i])
            if i == run.startIndex { runPath.move(to: center) }
            else                   { runPath.addLine(to: center) }
        }

        let color = run.color.swiftUIColor
        let isInactive = run.signal == .inactive
        // An inactive run "wakes up" when the path has successfully reached
        // its matching target — at that point the whole path reads as solved
        // and should brighten, even if the final signal is inactive (because
        // the target requires an inactive signal).
        let isSolvedInactive = isInactive && path.isComplete

        // Stroke is always solid. Inactive signals are rendered solid-but-dim
        // so the visual difference is a dimming cue, not a dash pattern.
        let haloOpacity: Double
        let coreOpacity: Double
        if isInactive && !isSolvedInactive {
            haloOpacity = 0.10
            coreOpacity = 0.40
        } else {
            haloOpacity = 0.30
            coreOpacity = 1.00
        }

        let coreStyle = StrokeStyle(
            lineWidth: cellSize * 0.28,
            lineCap: .round, lineJoin: .round
        )

        var glowCtx = context
        glowCtx.opacity = haloOpacity
        glowCtx.stroke(
            runPath,
            with: .color(color),
            style: StrokeStyle(lineWidth: cellSize * 0.55, lineCap: .round, lineJoin: .round)
        )

        var coreCtx = context
        coreCtx.opacity = coreOpacity
        coreCtx.stroke(runPath, with: .color(color), style: coreStyle)
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
