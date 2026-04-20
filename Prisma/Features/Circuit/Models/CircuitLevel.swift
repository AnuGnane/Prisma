//
//  CircuitLevel.swift
//  Prisma
//
//  Level definition and loading for Circuit.
//  Local levels load from circuit_levels.json; daily levels from CircuitLevelGenerator.
//

import Foundation

// MARK: - Level Definition

/// A complete Circuit puzzle definition.
struct CircuitLevel: Codable, Identifiable {
    /// Unique level identifier. Daily levels use negative IDs to avoid collision.
    let id: Int
    /// Grid dimension (grid is always square: size × size).
    let size: Int
    /// RNG seed used to generate this level (stored for reproducibility).
    let seed: Int
    /// Initial cell states for all cells in row-major order (size × size).
    let grid: [[CircuitCellData]]
    /// Terminal connection pairs that must all be powered for completion.
    let terminalPairs: [TerminalPair]
    /// Pre-computed solution JSON representing [NeonColor: ActivePath] 
    var solutionStateJSON: String?

    // MARK: Computed

    var totalCells: Int { size * size }

    /// Converts the serialisable `CircuitCellData` grid into an in-memory `[[CellState]]`.
    func makeLiveGrid() -> [[CellState]] {
        grid.map { row in row.map { $0.toCellState() } }
    }
}

// MARK: - Serialisable Cell Data

/// A Codable wrapper that can represent any CellState for JSON storage.
/// Using a tagged-union struct keeps the JSON human-readable and versionable.
struct CircuitCellData: Codable {
    enum CellKind: String, Codable {
        case empty
        case waypoint
        case source
        case target
        case notGate
        case bridge
        case synthesizer
    }

    let kind: CellKind

    // Terminal / Gate fields (only set when kind requires them)
    let color: NeonColor?
    let signal: SignalState?
    let outputColor: NeonColor?
    let outputSignal: SignalState?
    let gateDirection: GateDirection?
    let synthLogic: SynthesizerLogic?

    init(kind: CellKind,
         color: NeonColor? = nil,
         signal: SignalState? = nil,
         outputColor: NeonColor? = nil,
         outputSignal: SignalState? = nil,
         gateDirection: GateDirection? = nil,
         synthLogic: SynthesizerLogic? = nil) {
        self.kind = kind
        self.color = color
        self.signal = signal
        self.outputColor = outputColor
        self.outputSignal = outputSignal
        self.gateDirection = gateDirection
        self.synthLogic = synthLogic
    }

    func toCellState() -> CellState {
        switch kind {
        case .empty:
            return .empty
        case .waypoint:
            return .waypoint(visited: false)
        case .source:
            return .terminal(color: color ?? .blue, signal: signal ?? .active, isSource: true)
        case .target:
            return .terminal(color: color ?? .blue, signal: signal ?? .active, isSource: false)
        case .notGate:
            return .gate(type: .notGate(direction: gateDirection), state: .idle)
        case .bridge:
            return .gate(type: .bridge, state: .bridgeLocked(horizontalSignal: nil, verticalSignal: nil))
        case .synthesizer:
            return .gate(
                type: .synthesizer(
                    logic: synthLogic ?? .or,
                    outputSignal: outputSignal ?? .active
                ),
                state: .idle
            )
        }
    }

    // MARK: Factory helpers for building levels in code

    static let empty = CircuitCellData(kind: .empty)
    static let waypoint = CircuitCellData(kind: .waypoint)
    static func source(_ color: NeonColor, _ signal: SignalState) -> CircuitCellData {
        CircuitCellData(kind: .source, color: color, signal: signal)
    }
    static func target(_ color: NeonColor, _ signal: SignalState) -> CircuitCellData {
        CircuitCellData(kind: .target, color: color, signal: signal)
    }
    static func notGate(_ direction: GateDirection? = nil) -> CircuitCellData {
        CircuitCellData(kind: .notGate, gateDirection: direction)
    }
    static let bridge = CircuitCellData(kind: .bridge)
    static func synthesizer(logic: SynthesizerLogic, outputSignal: SignalState) -> CircuitCellData {
        CircuitCellData(kind: .synthesizer, outputSignal: outputSignal, synthLogic: logic)
    }
}

// MARK: - Level Loader

struct CircuitLevelLoader {
    private static var cachedLevels: [CircuitLevel]?

    // MARK: Local Archive

    static func load() -> [CircuitLevel] {
        if let cached = cachedLevels { return cached }

        // Try loading from the bundle JSON asset
        if let url = Bundle.main.url(forResource: "circuit_levels", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let levels = try? JSONDecoder().decode([CircuitLevel].self, from: data) {
            cachedLevels = levels
            return levels
        }

        // Fall back to hardcoded levels
        print("[Circuit] circuit_levels.json not found — using hardcoded fallback levels.")
        let fallback = CircuitLevelLoader.hardcodedFallbackLevels()
        cachedLevels = fallback
        return fallback
    }

    static func level(for id: Int) -> CircuitLevel? {
        load().first { $0.id == id }
    }

    // MARK: Daily

    /// Returns today's daily Circuit level generated deterministically from the date.
    static func dailyLevel(for date: Date = .now) -> CircuitLevel {
        CircuitLevelGenerator.generate(for: date)
    }

    // MARK: Hardcoded Fallback Levels

    /// A small set of hardcoded easy levels used when the JSON asset is missing.
    /// These are intentionally simple and act as the smoke-test during development.
    private static func hardcodedFallbackLevels() -> [CircuitLevel] {
        // Level 1: 5×5, two pairs, NOT gate in the middle
        // Blue active: (0,0) → (4,4)  |  Red inactive: (0,4) → (4,0)
        // NOT gate at (2,2)
        typealias C = CircuitCellData
        let g1: [[C]] = [
            [.source(.blue, .active),    .empty, .empty, .empty, .source(.red, .inactive)],
            [.empty,                     .empty, .empty, .empty, .empty                      ],
            [.empty,                     .empty, .notGate(), .empty, .empty                 ],
            [.empty,                     .empty, .empty, .empty, .empty                      ],
            [.target(.blue, .active),    .empty, .empty, .empty, .target(.red, .inactive)],
        ]
        let level1 = CircuitLevel(
            id: 1, size: 5, seed: 1001,
            grid: g1,
            terminalPairs: [
                TerminalPair(source: GridPosition(0, 0), target: GridPosition(4, 4), color: .blue, signal: .active),
                TerminalPair(source: GridPosition(0, 4), target: GridPosition(4, 0), color: .red, signal: .inactive),
            ]
        )

        // Level 2: 5×5, single pair with forced NOT gate traversal
        // Blue active source at (0,0), target at (4,4) requiring INACTIVE blue
        // NOT gate at (2,2) inverts: active → inactive
        let g2: [[C]] = [
            [.source(.blue, .active),    .empty, .empty, .empty, .empty],
            [.empty,                     .empty, .empty, .empty, .empty],
            [.empty,                     .empty, .notGate(), .empty, .empty],
            [.empty,                     .empty, .empty, .empty, .empty],
            [.empty,                     .empty, .empty, .empty, .target(.blue, .inactive)],
        ]
        let level2 = CircuitLevel(
            id: 2, size: 5, seed: 1002,
            grid: g2,
            terminalPairs: [
                TerminalPair(source: GridPosition(0, 0), target: GridPosition(4, 4), color: .blue, signal: .inactive),
            ]
        )

        return [level1, level2]
    }
}
