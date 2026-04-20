//
//  CircuitModels.swift
//  Prisma
//
//  Core value types for the Circuit mini-game.
//  All types are pure value types (struct/enum) — no SwiftUI or SwiftData imports needed here.
//  Separating these from the ViewModel keeps the logic layer independently testable.
//

import Foundation

// MARK: - Color Model

/// The visual color of a circuit path.
/// Drawn from Prisma's existing palette — restrained neon, not fully saturated.
enum NeonColor: String, Codable, CaseIterable, Hashable {
    // Primary colors
    case blue
    case red
    case yellow

    // Secondary colors
    case green
    case orange
    case purple

    /// Backward-compatible decoding for legacy persisted values.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let resolved = NeonColor(legacyRawValue: rawValue) {
            self = resolved
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown NeonColor: \(rawValue)"
            )
        }
    }

    /// Maps a raw string (including legacy palette names) to a current `NeonColor`.
    /// Returns `nil` for unknown values. Used by both `init(from:)` and by
    /// `CircuitState.pathOrder` decoding so old saves still migrate cleanly.
    init?(legacyRawValue rawValue: String) {
        switch rawValue {
        // Current palette
        case "blue": self = .blue
        case "red": self = .red
        case "yellow": self = .yellow
        case "green": self = .green
        case "orange": self = .orange
        case "purple": self = .purple

        // Legacy palette mapping
        case "cyan": self = .blue
        case "magenta": self = .red
        case "amber": self = .yellow
        case "violet": self = .purple
        case "coral": self = .orange
        default: return nil
        }
    }

    private enum PrimaryChannel: Hashable {
        case blue
        case red
        case yellow
    }

    private var primaryChannels: Set<PrimaryChannel> {
        switch self {
        case .blue:   return [.blue]
        case .red:    return [.red]
        case .yellow: return [.yellow]
        case .green:  return [.blue, .yellow]
        case .orange: return [.red, .yellow]
        case .purple: return [.blue, .red]
        }
    }

    /// Deterministic additive-style color mixing used by Synthesizer gates.
    func mixed(with other: NeonColor) -> NeonColor {
        let union = primaryChannels.union(other.primaryChannels)
        switch union {
        case [.blue]:            return .blue
        case [.red]:             return .red
        case [.yellow]:          return .yellow
        case [.blue, .red]:      return .purple
        case [.red, .yellow]:    return .orange
        case [.blue, .yellow]:   return .green
        case [.blue, .red, .yellow]:
            // Tertiary mixes are intentionally unsupported for v1 of the model.
            // Keep current color to avoid surprising transformations.
            return self
        default:
            return self
        }
    }
}

// MARK: - Signal Model

/// The logical state of a circuit signal.
/// Separated from NeonColor so the rendering (color) and logic (signal) can evolve independently.
enum SignalState: String, Codable, Hashable {
    case active
    case inactive
}

/// A fully-described signal at any point along a drawn path.
struct PathSignal: Codable, Hashable {
    let color: NeonColor
    let signal: SignalState
    /// True when a gate has modified this signal — used for rendering subtle visual distinctions.
    let wasTransformed: Bool

    init(color: NeonColor, signal: SignalState, wasTransformed: Bool = false) {
        self.color = color
        self.signal = signal
        self.wasTransformed = wasTransformed
    }

    enum CodingKeys: String, CodingKey {
        case color
        case signal
        case wasTransformed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = try container.decode(NeonColor.self, forKey: .color)
        signal = try container.decode(SignalState.self, forKey: .signal)
        wasTransformed = try container.decodeIfPresent(Bool.self, forKey: .wasTransformed) ?? false
    }
}

// MARK: - Gate Types

/// Direction a gate constrains traversal.
/// When a constrained gate is traversed in the wrong direction it passes signal unchanged.
enum GateDirection: String, Codable, Hashable, CaseIterable {
    case leftToRight
    case rightToLeft
    case topToBottom
    case bottomToTop

    /// The axis this direction operates on.
    var isHorizontal: Bool {
        self == .leftToRight || self == .rightToLeft
    }
}

/// Boolean logic used by a Synthesizer gate.
enum SynthesizerLogic: String, Codable, Hashable {
    case or   // output active if either input is active
    case xor  // output active if exactly one input is active
}

/// The type of a logic gate cell.
enum GateType: Codable, Hashable {
    /// Inverts the SignalState. Direction constraint is optional; nil = unconstrained.
    case notGate(direction: GateDirection?)
    /// Allows one horizontal and one vertical path to cross without mixing.
    case bridge
    /// Requires two input paths; emits a merged output with color from mix logic.
    case synthesizer(logic: SynthesizerLogic, outputSignal: SignalState)
}

/// The live runtime state of a gate cell.
enum GateState: Codable, Hashable {
    /// No path has entered the gate.
    case idle
    /// One of two required Synthesizer inputs has arrived.
    case partiallyFilled(arrivedInputs: [PathSignal])
    /// Gate is actively passed through and has resolved an output.
    case active(outputColor: NeonColor, outputSignal: SignalState)
    /// Bridge gate: two independent paths are tracked per axis.
    case bridgeLocked(horizontalSignal: PathSignal?, verticalSignal: PathSignal?)
}

// MARK: - Grid Position

/// A row/column address within the Circuit grid.
struct GridPosition: Hashable, Codable, Equatable {
    let row: Int
    let col: Int

    init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }

    /// Returns the position offset by the given deltas, clamped to the grid bounds.
    func offset(dRow: Int, dCol: Int) -> GridPosition {
        GridPosition(row + dRow, col + dCol)
    }

    /// True when `other` is directly adjacent (up/down/left/right).
    func isAdjacent(to other: GridPosition) -> Bool {
        (abs(row - other.row) == 1 && col == other.col) ||
        (abs(col - other.col) == 1 && row == other.row)
    }

    /// The cardinal direction from self to `other` (nil if not adjacent).
    func directionTo(_ other: GridPosition) -> GateDirection? {
        if other.row == row && other.col == col + 1 { return .leftToRight }
        if other.row == row && other.col == col - 1 { return .rightToLeft }
        if other.col == col && other.row == row + 1 { return .topToBottom }
        if other.col == col && other.row == row - 1 { return .bottomToTop }
        return nil
    }
}

// MARK: - Path Direction

/// How to render the path segment in this cell (which corners to connect).
enum PathDirection: String, Codable, Hashable {
    case horizontal   // ─
    case vertical     // │
    case turnNE       // ╰  (coming from south, exiting east)
    case turnNW       // ╯  (coming from south, exiting west)
    case turnSE       // ╭  (coming from north, exiting east)
    case turnSW       // ╮  (coming from north, exiting west)
    case startCap     // ◉  source terminal
    case endCap       // ◎  target terminal when reached

    /// Derive a PathDirection from an entry edge and an exit edge.
    /// entry = direction *from* which the path arrived; exit = direction the path is leaving.
    static func from(entry: GateDirection?, exit: GateDirection?) -> PathDirection {
        switch (entry, exit) {
        case (nil, nil):                                   return .horizontal
        case (.leftToRight, .leftToRight),
             (.rightToLeft, .rightToLeft):                 return .horizontal
        case (.topToBottom, .topToBottom),
             (.bottomToTop, .bottomToTop):                 return .vertical
        case (.bottomToTop, .leftToRight),
             (.rightToLeft, .topToBottom):                 return .turnSE
        case (.bottomToTop, .rightToLeft),
             (.leftToRight, .topToBottom):                 return .turnSW
        case (.topToBottom, .leftToRight),
             (.rightToLeft, .bottomToTop):                 return .turnNE
        case (.topToBottom, .rightToLeft),
             (.leftToRight, .bottomToTop):                 return .turnNW
        case (nil, _):                                     return .startCap
        case (_, nil):                                     return .endCap
        default:                                           return .horizontal
        }
    }
}

// MARK: - Cell State

/// The complete state of a single grid cell.
enum CellState: Codable, Hashable {
    /// No entity — can be freely drawn over.
    case empty

    /// A mandatory visit cell; does not transform the signal.
    case waypoint(visited: Bool)

    /// Source or target terminal with an expected color and signal.
    case terminal(
        color: NeonColor,
        signal: SignalState,
        isSource: Bool,
        // When this target terminal is reached: what signal actually arrived?
        // nil if unpowered; non-nil if any path has reached this cell.
        arrivedSignal: PathSignal? = nil
    )

    /// A segment of the player's drawn path.
    case path(signal: PathSignal, direction: PathDirection)

    /// A logic gate.
    case gate(type: GateType, state: GateState)

    // MARK: Convenience accessors

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    var isSource: Bool {
        if case .terminal(_, _, true, _) = self { return true }
        return false
    }

    var isTarget: Bool {
        if case .terminal(_, _, false, _) = self { return true }
        return false
    }

    var terminalColor: NeonColor? {
        if case .terminal(let c, _, _, _) = self { return c }
        return nil
    }

    var terminalSignal: SignalState? {
        if case .terminal(_, let s, _, _) = self { return s }
        return nil
    }

    var isPathSegment: Bool {
        if case .path = self { return true }
        return false
    }

    var pathSignal: PathSignal? {
        if case .path(let s, _) = self { return s }
        return nil
    }

    var isGate: Bool {
        if case .gate = self { return true }
        return false
    }

    var gateType: GateType? {
        if case .gate(let t, _) = self { return t }
        return nil
    }

    var gateState: GateState? {
        if case .gate(_, let s) = self { return s }
        return nil
    }

    var isWaypoint: Bool {
        if case .waypoint = self { return true }
        return false
    }

    var waypointVisited: Bool {
        if case .waypoint(let v) = self { return v }
        return false
    }
}

// MARK: - Active Path

/// Represents the player's current live drawing for a single color.
struct ActivePath: Identifiable, Codable {
    var id: UUID = UUID()
    /// Color this path was started from.
    let sourceColor: NeonColor
    /// Signal state at the source terminal.
    let sourceSignal: SignalState
    /// Ordered grid positions from source terminal to current draw head.
    var segments: [GridPosition]
    /// The evolved signal at the current head (may differ from source if gates were passed).
    var currentSignal: PathSignal
    /// True when this path has successfully powered a matching target terminal.
    var isComplete: Bool = false

    init(sourceColor: NeonColor, sourceSignal: SignalState, startPosition: GridPosition) {
        self.sourceColor = sourceColor
        self.sourceSignal = sourceSignal
        self.segments = [startPosition]
        self.currentSignal = PathSignal(color: sourceColor, signal: sourceSignal)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sourceColor
        case sourceSignal
        case segments
        case currentSignal
        case isComplete
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.sourceColor = try container.decode(NeonColor.self, forKey: .sourceColor)
        self.sourceSignal = try container.decode(SignalState.self, forKey: .sourceSignal)
        self.segments = try container.decode([GridPosition].self, forKey: .segments)
        self.currentSignal = try container.decode(PathSignal.self, forKey: .currentSignal)
        self.isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
    }

    var headPosition: GridPosition? { segments.last }
    var length: Int { segments.count }

    /// True if this path visits the given position.
    func contains(_ position: GridPosition) -> Bool {
        segments.contains(position)
    }

    /// The index of a position within this path, if it exists.
    func indexOfSegment(_ position: GridPosition) -> Int? {
        segments.firstIndex(of: position)
    }
}

// MARK: - Terminal Pair

/// Describes a source → target connection that must be made.
struct TerminalPair: Codable, Hashable {
    let source: GridPosition
    let target: GridPosition
    let color: NeonColor
    let signal: SignalState
}
