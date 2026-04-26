//
//  CircuitCanvasView.swift
//  Prisma
//
//  Draws all active path segments as glowing neon strokes using SwiftUI Canvas.
//  Using Canvas (not per-cell views) keeps rendering smooth even on large grids.
//
//  Neon glow effect: three-pass rendering (Cyberpunk / HUD-FUI style)
//    Pass 1: ambient halo — very wide, very low opacity (0.46 × cellSize, ~8% active)
//    Pass 2: bloom       — medium, semi-transparent  (0.34 × cellSize, ~30% active)
//    Pass 3: core        — narrow, fully opaque       (0.24 × cellSize, 100% active)
//
//  Inactive signals render at reduced opacity so the path reads as "present but
//  unlit" — core 58%, bloom 18%, ambient 3%.  A solved inactive path (matched
//  target) snaps to full brightness.
//
//  Gate stub drawing:
//    When a path enters or exits a gate cell the stroke terminates at the gate's
//    visual border (portOffset = 0.42 × cellSize from the gate centre).
//    GateCellView draws coloured edge-connector bars to bridge the remaining gap.
//
//  Color-transition fix:
//    Run boundaries sit at the gate cell itself (not the pre-gate cell), so only
//    one colour is ever painted in the pre-gate cell.  Each run's tail is extended
//    to the adjacent gate's entry port so there is no visual gap at the boundary.
//

import SwiftUI

struct CircuitCanvasView: View {
    let activePaths: [NeonColor: ActivePath]
    /// Per-position signal map from the ViewModel's pathLayer.
    let pathLayer: [GridPosition: PathSignal]
    let gridSize: Int
    let cellSize: CGFloat
    /// Positions of gate cells — stubs are drawn here so the gate icon is
    /// visible in the gap rather than being obscured by the path stroke.
    let gateCells: Set<GridPosition>

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

        let runs = buildSegmentRuns(for: path)
        for run in runs {
            drawRun(run, path: path, in: context)
        }
        // Note: the old dashed "transformed-segment shimmer" overlay has been removed.
        // Round dashes at cellSize × 0.10 with lineCap .round collapse into evenly-
        // spaced circles (the "bead" glitch). Gates communicate signal transformation
        // through their own tint + glow — no additional overlay needed.
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
                // Start the new run AT index i (the gate), not i-1.
                // This prevents the pre-gate cell from being painted by two colours.
                // buildStubPath extends each run's tail to the adjacent gate port so
                // there is no visual gap at the boundary.
                runStart = i
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

    // MARK: - Three-Pass Neon Drawing

    private func drawRun(_ run: SegmentRun, path: ActivePath, in context: GraphicsContext) {
        guard run.endIndex > run.startIndex else { return }

        let runPath = buildStubPath(run: run, path: path)
        let color   = run.color.swiftUIColor
        let isInactive       = run.signal == .inactive
        let isSolvedInactive = isInactive && path.isComplete

        // ── Opacity values ────────────────────────────────────────────────────
        // Active:          ambient 8%,  bloom 30%, core 100%
        // Inactive:        ambient 3%,  bloom 18%, core 58%
        //   → dim enough to read as "unlit", bright enough to track the wire
        // Solved-inactive: treated identically to active (path is resolved)
        let ambientOpacity: Double = (isInactive && !isSolvedInactive) ? 0.03 : 0.08
        let bloomOpacity:   Double = (isInactive && !isSolvedInactive) ? 0.18 : 0.30
        let coreOpacity:    Double = (isInactive && !isSolvedInactive) ? 0.58 : 1.00

        // Pass 1 — ambient halo (sets the glow atmosphere without heavy bleed)
        var ambientCtx = context
        ambientCtx.opacity = ambientOpacity
        ambientCtx.stroke(runPath, with: .color(color),
                          style: StrokeStyle(lineWidth: cellSize * 0.46,
                                            lineCap: .round, lineJoin: .round))

        // Pass 2 — bloom (the bright aura that defines the neon tube shape)
        var bloomCtx = context
        bloomCtx.opacity = bloomOpacity
        bloomCtx.stroke(runPath, with: .color(color),
                        style: StrokeStyle(lineWidth: cellSize * 0.34,
                                           lineCap: .round, lineJoin: .round))

        // Pass 3 — core (crisp, sharp inner wire)
        var coreCtx = context
        coreCtx.opacity = coreOpacity
        coreCtx.stroke(runPath, with: .color(color),
                       style: StrokeStyle(lineWidth: cellSize * 0.24,
                                          lineCap: .round, lineJoin: .round))
    }

    // MARK: - Stub-aware Path Building

    /// Builds a potentially-disconnected Path that creates visual stubs around gate cells.
    /// When the run passes through a gate the pen is lifted so the gate icon is unobscured,
    /// then resumed at the exit port on the other side.
    ///
    /// Color-transition tail extension:
    ///   After the main loop, if the run ends immediately before a gate cell the path is
    ///   extended to that gate's entry port in the run's colour so there is no gap.
    private func buildStubPath(run: SegmentRun, path: ActivePath) -> Path {
        var result  = Path()
        var penIsUp = true

        for i in run.startIndex...run.endIndex {
            let pos    = path.segments[i]
            let isGate = gateCells.contains(pos)

            if isGate {
                // ── Entry stub: draw from previous cell to the gate's entry port ──
                if i > run.startIndex {
                    let prev      = path.segments[i - 1]
                    let entryPort = portPoint(of: pos, facing: prev)
                    if penIsUp {
                        result.move(to: entryPort)
                        penIsUp = false
                    } else {
                        result.addLine(to: entryPort)
                    }
                }
                // Lift the pen — gate interior belongs to GateCellView
                penIsUp = true

            } else {
                // ── Normal (non-gate) cell ──
                let center     = cellCenter(for: pos)
                let prevIsGate = i > run.startIndex && gateCells.contains(path.segments[i - 1])

                if penIsUp || prevIsGate {
                    if prevIsGate {
                        // Resume from the gate's exit port
                        let exitPort = portPoint(of: path.segments[i - 1], facing: pos)
                        result.move(to: exitPort)
                        result.addLine(to: center)
                    } else {
                        result.move(to: center)
                    }
                    penIsUp = false
                } else {
                    result.addLine(to: center)
                }
            }
        }

        // ── Color-transition tail extension ──────────────────────────────────
        // Extend the run to the next gate's entry port when the run ends just
        // before a gate so the stub is flush with the gate's visual border.
        if !penIsUp {
            let nextIdx = run.endIndex + 1
            if nextIdx < path.segments.count {
                let gatePos = path.segments[nextIdx]
                if gateCells.contains(gatePos) {
                    let entryPort = portPoint(of: gatePos, facing: path.segments[run.endIndex])
                    result.addLine(to: entryPort)
                }
            }
        }

        return result
    }

    /// Returns the point on the visual boundary of `special` (a gate cell) that faces
    /// toward `other`.  Path stubs terminate here; the offset (42 % of cellSize) sits
    /// just outside the gate's rounded-rectangle background (which ends at 39 %).
    /// The gate's opaque dark base masks the stroke's round cap, which extends inward.
    private func portPoint(of special: GridPosition, facing other: GridPosition) -> CGPoint {
        let center = cellCenter(for: special)
        let dx = CGFloat(other.col - special.col)
        let dy = CGFloat(other.row - special.row)
        return CGPoint(
            x: center.x + dx * cellSize * 0.42,
            y: center.y + dy * cellSize * 0.42
        )
    }

    // MARK: - Helpers

    /// Draws a dot at the source terminal position when only the start tap is registered.
    private func drawStartDot(at position: GridPosition, signal: PathSignal, in context: GraphicsContext) {
        let center = cellCenter(for: position)
        let radius = cellSize * 0.14
        let rect   = CGRect(x: center.x - radius, y: center.y - radius,
                            width: radius * 2, height: radius * 2)
        var dotCtx = context
        dotCtx.opacity = 0.70
        dotCtx.fill(Path(ellipseIn: rect), with: .color(signal.color.swiftUIColor))
    }

    private func cellCenter(for position: GridPosition) -> CGPoint {
        CGPoint(
            x: (CGFloat(position.col) + 0.5) * cellSize,
            y: (CGFloat(position.row) + 0.5) * cellSize
        )
    }

    /// Returns the PathSignal at an index by reading the ViewModel's pathLayer.
    ///
    /// Fallback: Source terminals are never added to pathLayer by design. `currentSignal`
    /// is the *evolved* post-gate signal at the draw head — using it as a fallback for
    /// index 0 (the source terminal) creates a spurious run boundary between index 0 and
    /// index 1, generating a single-cell Run[0,0] that silently fails the
    /// `endIndex > startIndex` guard. The entire source-to-gate wire becomes invisible.
    ///
    /// Correct fallback: `PathSignal(color: sourceColor, signal: sourceSignal)` — the
    /// pre-gate signal that the source terminal actually emits. This groups the source
    /// cell into the same run as the cells leading up to the first gate.
    private func signalAt(index: Int, in path: ActivePath) -> PathSignal {
        let pos = path.segments[index]
        if let signal = pathLayer[pos] { return signal }
        return PathSignal(color: path.sourceColor, signal: path.sourceSignal)
    }
}
