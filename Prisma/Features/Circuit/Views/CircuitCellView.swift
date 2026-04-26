//
//  CircuitCellView.swift
//  Prisma
//
//  Renders the static, non-path entity for a single grid cell:
//    - Terminal rings (source and target)
//    - Gate icons (NOT, Bridge, Synthesizer, Spark) with active glow + port connectors
//    - Waypoint markers (tints to path colour when visited)
//    - Empty cells (transparent, gesture hit-targets only)
//
//  IMPORTANT: This view does NOT draw path segments.
//  All path rendering lives in CircuitCanvasView (single Canvas overlay).
//
//  Gate visual design — Cyberpunk / HUD-FUI style:
//    Layer 0: Outer glow halo  — large shadow on border, only when active
//    Layer 1: Opaque dark base — near-black fill that MASKS the Canvas stroke round cap
//             (this is the critical fix: the Canvas path's round cap extends into the gate
//              area; without this opaque base it would show through the translucent tint)
//    Layer 2: Signal colour tint — a translucent colour layer on top of the dark base
//    Layer 3: Border ring       — full-opacity signal colour border, carries the glow
//    Layer 4: Gate icon         — retains type-specific identity colour
//    Layer 5: Edge connectors   — coloured bars that bridge the stub gap on active sides
//    Layer 6: Preview badge / synth partial indicator
//
//  Edge connector geometry (must match CircuitCanvasView core stroke width 0.24):
//    gate bg radius from centre = size × 0.39
//    portPoint (stub end)        = size × 0.42 from gate centre
//    cell edge                   = size × 0.50 from gate centre
//    connector spans gate border → cell edge: size × 0.11 wide
//    connector centre from gate centre = size × 0.445
//    connector cross-section (pathW)   = size × 0.24  ← matches Canvas core
//

import SwiftUI

struct CircuitCellView: View {
    let cell: CellState
    let cellSize: CGFloat
    let isPreviewingGateOutput: Bool
    let previewOutputSignal: PathSignal?
    /// Active-path edge connections for gate cells.
    /// Key = which edge of this cell the path connects from/to.
    /// Value = the colour of the signal on that connection.
    var activeEdges: [Edge: Color] = [:]
    /// The colour of the path signal currently passing through a waypoint cell, or nil.
    var activePathColor: Color? = nil

    var body: some View {
        switch cell {
        case .empty:
            // Subtle grid dot — helps players read the grid
            Circle()
                .fill(.primary.opacity(0.05))
                .frame(width: cellSize * 0.10, height: cellSize * 0.10)
                .frame(width: cellSize, height: cellSize)

        case .waypoint(let visited):
            WaypointMarker(size: cellSize, visited: visited, activeColor: activePathColor)

        case .terminal(let color, let signal, let isSource, let arrived):
            TerminalView(
                color: color,
                signal: signal,
                isSource: isSource,
                arrived: arrived,
                size: cellSize
            )

        case .path:
            // Path segments are rendered by CircuitCanvasView — nothing here
            Color.clear.frame(width: cellSize, height: cellSize)

        case .gate(let gateType, let state):
            GateCellView(
                gateType: gateType,
                gateState: state,
                size: cellSize,
                isPreviewing: isPreviewingGateOutput,
                previewSignal: previewOutputSignal,
                activeEdges: activeEdges
            )
        }
    }
}

// MARK: - Terminal View

private struct TerminalView: View {
    let color: NeonColor
    let signal: SignalState
    let isSource: Bool
    let arrived: PathSignal?
    let size: CGFloat

    private var neonColor: Color { color.swiftUIColor }
    private var isPowered: Bool {
        guard let a = arrived else { return false }
        return a.color == color && a.signal == signal
    }
    private var isWrongState: Bool { arrived != nil && !isPowered }

    var body: some View {
        ZStack {
            // Outer ambient glow when powered
            if isPowered {
                Circle()
                    .fill(neonColor.opacity(0.18))
                    .frame(width: size * 0.90, height: size * 0.90)
                    .blur(radius: size * 0.08)
            }

            // Main ring
            Circle()
                .stroke(ringColor, lineWidth: size * 0.09)
                .frame(width: size * 0.66, height: size * 0.66)
                .shadow(color: isPowered ? neonColor.opacity(0.70) : .clear, radius: size * 0.14)

            // Inner fill for source (solid dot) or target (powered dot)
            if isSource {
                Circle()
                    .fill(neonColor)
                    .frame(width: size * 0.30, height: size * 0.30)
                    .shadow(color: neonColor.opacity(0.60), radius: 4)
            } else if isPowered {
                Circle()
                    .fill(neonColor)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .shadow(color: neonColor.opacity(0.85), radius: 6)
            }

            // Inactive signal indicator
            if signal == .inactive {
                Image(systemName: "minus.circle")
                    .font(.system(size: size * 0.16, weight: .bold))
                    .foregroundStyle(neonColor.opacity(0.80))
                    .offset(x: size * 0.20, y: -size * 0.20)
            }
        }
        .frame(width: size, height: size)
    }

    private var ringColor: Color {
        if isPowered    { return neonColor }
        if isWrongState { return neonColor.opacity(0.45) }
        return neonColor.opacity(0.65)
    }
}

// MARK: - Gate Cell View

private struct GateCellView: View {
    let gateType:    GateType
    let gateState:   GateState
    let size:        CGFloat
    let isPreviewing: Bool
    let previewSignal: PathSignal?
    var activeEdges: [Edge: Color] = [:]

    // MARK: State helpers

    private var isActive: Bool {
        if case .active = gateState { return true }
        return false
    }

    private var activeOutputColor: Color? {
        if case .active(let c, _) = gateState { return c.swiftUIColor }
        return nil
    }

    private var effectiveSignalColor: Color? {
        if let c = activeOutputColor { return c }
        if isPreviewing, let p = previewSignal { return p.color.swiftUIColor }
        return nil
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // ── Layer 0: Outer soft shadow glow (only when active) ────────────
            // Implemented as a shadow on the border ring below — see layer 3.

            // ── Layer 1: Opaque dark base ─────────────────────────────────────
            // This is the KEY fix: the Canvas path's round cap extends ~0.12×size
            // into the gate area from the portPoint.  Without an opaque base the
            // path would bleed visibly through the translucent tint above.
            RoundedRectangle(cornerRadius: size * 0.20)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.10))   // near-black, slight blue cast
                .frame(width: size * 0.78, height: size * 0.78)

            // ── Layer 2: Signal colour tint ───────────────────────────────────
            RoundedRectangle(cornerRadius: size * 0.20)
                .fill(gateTintColor)
                .frame(width: size * 0.78, height: size * 0.78)

            // ── Layer 3: Border ring (carries the glow via shadow) ────────────
            RoundedRectangle(cornerRadius: size * 0.20)
                .strokeBorder(gateBorderColor, lineWidth: size * 0.044)
                .frame(width: size * 0.78, height: size * 0.78)
                .shadow(color: activeShadowColor, radius: size * 0.22, x: 0, y: 0)

            // ── Layer 4: Gate icon ────────────────────────────────────────────
            gateIcon
                .font(.system(size: size * 0.29, weight: .bold))
                .foregroundStyle(gateIconColor)

            // ── Layer 5: Edge port connectors ─────────────────────────────────
            ForEach(sortedActiveEdges, id: \.0) { edge, color in
                edgeConnector(edge: edge, color: color)
            }

            // ── Layer 6a: Preview output badge ────────────────────────────────
            if isPreviewing, let preview = previewSignal {
                previewBadge(for: preview)
            }

            // ── Layer 6b: Synthesizer partial-fill indicator ──────────────────
            if case .partiallyFilled(let inputs) = gateState {
                synthPartialIndicator(inputs: inputs)
            }
        }
        .frame(width: size, height: size)
    }

    // Sorted for ForEach stability
    private var sortedActiveEdges: [(Edge, Color)] {
        let order: [Edge] = [.top, .bottom, .leading, .trailing]
        return order.compactMap { edge in activeEdges[edge].map { (edge, $0) } }
    }

    // MARK: Icon

    private var gateIcon: some View {
        let name: String
        switch gateType {
        case .notGate:     name = "arrow.triangle.2.circlepath"
        case .sparkGate:   name = "bolt.fill"
        case .bridge:      name = "arrow.triangle.branch"
        case .synthesizer: name = "arrow.triangle.merge"
        }
        return Image(systemName: name)
    }

    // MARK: Colours

    /// Translucent colour tint layered on top of the opaque dark base.
    private var gateTintColor: Color {
        // Active: output signal colour at moderate opacity
        if let out = activeOutputColor { return out.opacity(0.20) }
        // Preview: approaching signal at lower opacity
        if isPreviewing, let p = previewSignal { return p.color.swiftUIColor.opacity(0.12) }
        // Bridge locked: cyan tint
        if case .bridgeLocked = gateState { return Color.cyan.opacity(0.14) }
        // Idle: very subtle type-specific tint so players can distinguish gate types
        switch gateType {
        case .notGate:     return Color.orange.opacity(0.07)
        case .sparkGate:   return Color.yellow.opacity(0.09)
        case .bridge:      return Color.cyan.opacity(0.07)
        case .synthesizer: return Color.purple.opacity(0.09)
        }
    }

    /// Border colour — type-specific at idle so gates remain identifiable even unlit.
    private var gateBorderColor: Color {
        if let out = activeOutputColor          { return out.opacity(0.85) }
        if isPreviewing, let p = previewSignal  { return p.color.swiftUIColor.opacity(0.55) }
        if case .bridgeLocked = gateState       { return Color.cyan.opacity(0.65) }
        // Idle: low-opacity type colour (no plain grey — every gate has a personality)
        switch gateType {
        case .notGate:     return Color.orange.opacity(0.28)
        case .sparkGate:   return Color.yellow.opacity(0.28)
        case .bridge:      return Color.cyan.opacity(0.28)
        case .synthesizer: return Color.purple.opacity(0.28)
        }
    }

    /// Icon colour — preserves gate identity at a glance; state is communicated via border+glow.
    private var gateIconColor: Color {
        switch gateType {
        case .notGate:     return isActive ? .orange         : .orange.opacity(0.45)
        case .sparkGate:   return .yellow.opacity(isActive ? 1.0 : 0.55)
        case .bridge:      return isActive ? .cyan           : .cyan.opacity(0.45)
        case .synthesizer: return isActive ? .purple         : .purple.opacity(0.45)
        }
    }

    /// Shadow colour for the border glow — only when active or previewing.
    private var activeShadowColor: Color {
        if let c = effectiveSignalColor { return c.opacity(0.55) }
        return .clear
    }

    // MARK: Edge connectors

    /// Short coloured bar that fills the gap between the gate's rounded-rectangle border
    /// and the cell edge on each active side.  These bridge the visual gap created by the
    /// path stubs in CircuitCanvasView so the path appears to "plug into" the gate cleanly.
    ///
    /// Geometry:
    ///   gate bg radius = size × 0.39   (gate bg = size × 0.78)
    ///   portPoint dist = size × 0.42   (where Canvas stub terminates)
    ///   cell edge dist = size × 0.50
    ///   connector span = size × 0.11   (gate border → cell edge)
    ///   connector centre from gate centre = size × 0.445
    ///   connector cross-section (pathW)   = size × 0.24  ← matches Canvas core width
    private func edgeConnector(edge: Edge, color: Color) -> some View {
        let span   = size * 0.11   // gate border → cell edge
        let pathW  = size * 0.24   // must match CircuitCanvasView core lineWidth
        let gEdge  = size * 0.39   // distance from cell centre to gate border

        let (w, h, ox, oy): (CGFloat, CGFloat, CGFloat, CGFloat)
        switch edge {
        case .leading:
            (w, h) = (span, pathW)
            (ox, oy) = (-(gEdge + span / 2), 0)
        case .trailing:
            (w, h) = (span, pathW)
            (ox, oy) = (gEdge + span / 2, 0)
        case .top:
            (w, h) = (pathW, span)
            (ox, oy) = (0, -(gEdge + span / 2))
        case .bottom:
            (w, h) = (pathW, span)
            (ox, oy) = (0, gEdge + span / 2)
        }

        return RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: w, height: h)
            .shadow(color: color.opacity(0.55), radius: 3, x: 0, y: 0)
            .offset(x: ox, y: oy)
    }

    // MARK: Other overlays

    private func previewBadge(for signal: PathSignal) -> some View {
        Circle()
            .fill(signal.color.swiftUIColor)
            .frame(width: size * 0.20, height: size * 0.20)
            .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
            .shadow(color: signal.color.swiftUIColor.opacity(0.60), radius: 4)
            .offset(x: size * 0.28, y: size * 0.28)
    }

    private func synthPartialIndicator(inputs: [PathSignal]) -> some View {
        HStack(spacing: 3) {
            ForEach(inputs.indices, id: \.self) { i in
                Circle()
                    .fill(inputs[i].color.swiftUIColor)
                    .frame(width: size * 0.13, height: size * 0.13)
            }
            if inputs.count < 2 {
                Circle()
                    .stroke(.primary.opacity(0.28), lineWidth: 1)
                    .frame(width: size * 0.13, height: size * 0.13)
            }
        }
        .offset(y: size * 0.26)
    }
}

// MARK: - Waypoint Marker

private struct WaypointMarker: View {
    let size:    CGFloat
    let visited: Bool
    var activeColor: Color? = nil

    var body: some View {
        ZStack {
            // Subtle ambient ring when visited
            if visited, let color = activeColor {
                Circle()
                    .fill(color.opacity(0.10))
                    .frame(width: size * 0.68, height: size * 0.68)
            }

            // Outer ring
            Circle()
                .stroke(ringColor, lineWidth: size * 0.055)
                .frame(width: size * 0.46, height: size * 0.46)
                .shadow(color: visited ? (activeColor ?? .clear).opacity(0.50) : .clear, radius: 4)

            // Crosshair
            Rectangle()
                .fill(crosshairColor)
                .frame(width: size * 0.44, height: size * 0.038)
            Rectangle()
                .fill(crosshairColor)
                .frame(width: size * 0.038, height: size * 0.44)
        }
        .frame(width: size, height: size)
    }

    private var ringColor: Color {
        if visited, let color = activeColor { return color.opacity(0.85) }
        return .primary.opacity(visited ? 0.55 : 0.18)
    }

    private var crosshairColor: Color {
        if visited, let color = activeColor { return color.opacity(0.65) }
        return .primary.opacity(visited ? 0.45 : 0.12)
    }
}

// MARK: - NeonColor → SwiftUI Color

extension NeonColor {
    var swiftUIColor: Color {
        switch self {
        case .blue:   return Color(red: 0.16, green: 0.54, blue: 0.98)
        case .red:    return Color(red: 0.93, green: 0.28, blue: 0.32)
        case .yellow: return Color(red: 0.98, green: 0.76, blue: 0.20)
        case .green:  return Color(red: 0.24, green: 0.78, blue: 0.39)
        case .orange: return Color(red: 0.98, green: 0.56, blue: 0.18)
        case .purple: return Color(red: 0.55, green: 0.43, blue: 0.98)
        }
    }
}
