//
//  CircuitCellView.swift
//  Prisma
//
//  Renders the static, non-path entity for a single grid cell:
//    - Terminal rings (source and target)
//    - Gate icons (NOT, ColorShift, Bridge, Synthesizer)
//    - Waypoint markers
//    - Empty cells (transparent, gesture hit-targets only)
//
//  IMPORTANT: This view does NOT draw path segments.
//  All path rendering lives in CircuitCanvasView (single Canvas overlay).
//

import SwiftUI

struct CircuitCellView: View {
    let cell: CellState
    let cellSize: CGFloat
    let isPreviewingGateOutput: Bool     // true while drag is approaching this gate cell
    let previewOutputSignal: PathSignal? // computed output to preview on exit side

    var body: some View {
        switch cell {
        case .empty:
            // Subtle grid dot — helps players read the grid
            Circle()
                .fill(.primary.opacity(0.06))
                .frame(width: cellSize * 0.12, height: cellSize * 0.12)
                .frame(width: cellSize, height: cellSize)

        case .waypoint(let visited):
            WaypointMarker(size: cellSize, visited: visited)

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
                previewSignal: previewOutputSignal
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
    private var isWrongState: Bool {
        arrived != nil && !isPowered
    }

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(glowColor.opacity(isPowered ? 0.25 : 0.08))
                .frame(width: size * 0.88, height: size * 0.88)

            // Main ring
            Circle()
                .stroke(ringColor, lineWidth: size * 0.1)
                .frame(width: size * 0.68, height: size * 0.68)

            // Inner fill for source (solid) or target (hollow with smaller dot)
            if isSource {
                Circle()
                    .fill(neonColor)
                    .frame(width: size * 0.32, height: size * 0.32)
            } else if isPowered {
                Circle()
                    .fill(neonColor)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .shadow(color: neonColor.opacity(0.8), radius: 6)
            }

            // Signal state indicator (active = ●, inactive = ○)
            if signal == .inactive {
                // Small diagonal cross to indicate inactive expected signal
                Image(systemName: "minus.circle")
                    .font(.system(size: size * 0.18, weight: .bold))
                    .foregroundStyle(neonColor.opacity(0.8))
                    .offset(x: size * 0.22, y: -size * 0.22)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: isPowered ? neonColor.opacity(0.6) : .clear, radius: 8)
    }

    private var ringColor: Color {
        if isPowered    { return neonColor }
        if isWrongState { return neonColor.opacity(0.5) }
        return neonColor.opacity(0.7)
    }

    private var glowColor: Color {
        if let a = arrived { return a.color.swiftUIColor }
        return neonColor
    }
}

// MARK: - Gate Cell View

private struct GateCellView: View {
    let gateType: GateType
    let gateState: GateState
    let size: CGFloat
    let isPreviewing: Bool
    let previewSignal: PathSignal?

    private var isActive: Bool {
        if case .active = gateState { return true }
        return false
    }

    var body: some View {
        ZStack {
            // Gate background hexagon / square shape
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(gateBgColor)
                .frame(width: size * 0.78, height: size * 0.78)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .stroke(gateBorderColor, lineWidth: size * 0.055)
                )

            // Gate icon
            gateIcon
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(gateIconColor)

            // Preview swatch on exit side
            if isPreviewing, let preview = previewSignal {
                previewBadge(for: preview)
            }

            // Synthesizer partial fill indicator
            if case .partiallyFilled(let inputs) = gateState {
                synthPartialIndicator(inputs: inputs)
            }
        }
        .frame(width: size, height: size)
    }

    private var gateIcon: some View {
        let name: String
        switch gateType {
        case .notGate:      name = "exclamationmark.circle"
        case .colorShift:   name = "paintpalette"
        case .bridge:       name = "arrow.triangle.branch"
        case .synthesizer:  name = "arrow.triangle.merge"
        }
        return Image(systemName: name)
    }

    private var gateBgColor: Color {
        switch gateType {
        case .notGate:      return Color.primary.opacity(isActive ? 0.22 : 0.1)
        case .colorShift(let out): return out.swiftUIColor.opacity(isActive ? 0.25 : 0.1)
        case .bridge:       return Color.primary.opacity(isActive ? 0.22 : 0.1)
        case .synthesizer:  return Color.purple.opacity(isActive ? 0.25 : 0.1)
        }
    }

    private var gateBorderColor: Color {
        isActive ? gateIconColor.opacity(0.8) : .primary.opacity(0.2)
    }

    private var gateIconColor: Color {
        switch gateType {
        case .notGate:      return isActive ? .orange : .primary.opacity(0.55)
        case .colorShift(let out): return out.swiftUIColor
        case .bridge:       return isActive ? .cyan : .primary.opacity(0.55)
        case .synthesizer:  return isActive ? .purple : .primary.opacity(0.55)
        }
    }

    private func previewBadge(for signal: PathSignal) -> some View {
        Circle()
            .fill(signal.color.swiftUIColor)
            .frame(width: size * 0.22, height: size * 0.22)
            .overlay(
                Circle().stroke(.white.opacity(0.5), lineWidth: 1)
            )
            .offset(x: size * 0.3, y: size * 0.3)
    }

    private func synthPartialIndicator(inputs: [PathSignal]) -> some View {
        HStack(spacing: 3) {
            ForEach(inputs.indices, id: \.self) { i in
                Circle()
                    .fill(inputs[i].color.swiftUIColor)
                    .frame(width: size * 0.14, height: size * 0.14)
            }
            // Empty slot for the missing input
            if inputs.count < 2 {
                Circle()
                    .stroke(.primary.opacity(0.3), lineWidth: 1)
                    .frame(width: size * 0.14, height: size * 0.14)
            }
        }
        .offset(y: size * 0.28)
    }
}

// MARK: - Waypoint Marker

private struct WaypointMarker: View {
    let size: CGFloat
    let visited: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(visited ? 0.6 : 0.2), lineWidth: size * 0.06)
                .frame(width: size * 0.48, height: size * 0.48)

            // Crosshair lines
            Rectangle()
                .fill(.primary.opacity(visited ? 0.5 : 0.15))
                .frame(width: size * 0.48, height: size * 0.04)
            Rectangle()
                .fill(.primary.opacity(visited ? 0.5 : 0.15))
                .frame(width: size * 0.04, height: size * 0.48)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - NeonColor → SwiftUI Color

extension NeonColor {
    var swiftUIColor: Color {
        switch self {
        case .cyan:    return Color(red: 0.0,  green: 0.78, blue: 1.0)
        case .magenta: return Color(red: 0.88, green: 0.25, blue: 0.98)
        case .amber:   return Color(red: 1.0,  green: 0.70, blue: 0.0)
        case .violet:  return Color(red: 0.49, green: 0.30, blue: 1.0)
        case .coral:   return Color(red: 1.0,  green: 0.43, blue: 0.43)
        }
    }
}
