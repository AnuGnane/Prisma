//
//  CircuitGameViewModel.swift
//  Prisma
//
//  Drives all Circuit game logic:
//    - Gesture-to-grid mapping
//    - Path drawing, truncation, and gate transforms
//    - Win condition evaluation (1–3 stars)
//    - Timer
//    - Daily and local level modes
//

import Foundation
import Observation

// MARK: - Game State

enum CircuitGameState: Equatable {
    case inProgress
    case completed(stars: Int)
}

// MARK: - ViewModel

@Observable @MainActor
final class CircuitGameViewModel {

    // MARK: - Configuration

    let isDaily: Bool
    let activeLevelId: Int?

    // MARK: - Level Data

    private(set) var level: CircuitLevel

    // MARK: - Live Grid State

    /// The mutable working grid updated as the player draws.
    /// Initialized from level.makeLiveGrid(); reset on resetLevel().
    private(set) var liveGrid: [[CellState]]

    // MARK: - Active Paths

    /// One active path per NeonColor (at most one path per color at any time).
    private(set) var activePaths: [NeonColor: ActivePath] = [:]

    /// The color currently being drawn (nil when no drag is in progress).
    private(set) var activeDrawColor: NeonColor? = nil

    // MARK: - Game State

    private(set) var gameState: CircuitGameState = .inProgress

    // MARK: - Timer

    private(set) var elapsedSeconds: Int = 0
    private var timerTask: Task<Void, Never>?

    // MARK: - Init (Daily)

    init(date: Date = .now) {
        self.isDaily = true
        self.activeLevelId = nil
        let lv = CircuitLevelLoader.dailyLevel(for: date)
        self.level = lv
        self.liveGrid = lv.makeLiveGrid()
        startTimer()
    }

    // MARK: - Init (Local Level)

    init(levelId: Int) {
        self.isDaily = false
        self.activeLevelId = levelId
        let lv = CircuitLevelLoader.level(for: levelId) ?? CircuitLevelGenerator.generate(for: .now)
        self.level = lv
        self.liveGrid = lv.makeLiveGrid()
        startTimer()
    }

    // MARK: - Derived Metrics

    var totalCells: Int { level.size * level.size }

    /// Number of cells that are occupied by a path segment (excludes terminals, gates).
    var filledPathCells: Int {
        liveGrid.flatMap { $0 }.filter { $0.isPathSegment }.count
    }

    /// Number of non-empty cells (paths + gates + terminals).
    var usedCells: Int {
        liveGrid.flatMap { $0 }.filter { !$0.isEmpty }.count
    }

    var coveragePercent: Double {
        Double(usedCells) / Double(totalCells)
    }

    var totalPathLength: Int {
        activePaths.values.reduce(0) { $0 + $1.length }
    }

    var poweredTerminalCount: Int {
        level.terminalPairs.filter { pair in
            guard case .terminal(let c, let s, false, let arrived) = liveGrid[pair.target.row][pair.target.col],
                  let a = arrived else { return false }
            return a.color == c && a.signal == s
        }.count
    }

    var allTerminalsPowered: Bool {
        poweredTerminalCount == level.terminalPairs.count
    }

    var isPerfectFlow: Bool {
        allTerminalsPowered && coveragePercent >= 1.0
    }

    var isMaxEfficiency: Bool {
        isPerfectFlow && totalPathLength <= level.parPathLength
    }

    var isGameOver: Bool {
        if case .completed = gameState { return true }
        return false
    }

    // MARK: - Timer UI

    var timerString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return "\(m):\(s.formatted(.number.precision(.integerLength(2))))"
    }

    // MARK: - Gesture Entry Points

    /// Called when the drag begins at a grid position.
    func dragBegan(at position: GridPosition) {
        guard !isGameOver else { return }
        guard isInBounds(position) else { return }
        let cell = liveGrid[position.row][position.col]

        switch cell {
        case .terminal(let color, let signal, true, _):
            // Starting from a source terminal
            startNewPath(color: color, signal: signal, at: position)
        case .path:
            // Picking up an existing path mid-segment — truncate to this point
            if let color = colorOfPath(at: position) {
                truncatePath(color: color, to: position)
                activeDrawColor = color
            }
        default:
            break
        }
    }

    /// Called as the drag moves to a new grid position.
    func dragMoved(to position: GridPosition) {
        guard !isGameOver else { return }
        guard let color = activeDrawColor else { return }
        guard isInBounds(position) else { return }
        guard let path = activePaths[color] else { return }
        guard let head = path.headPosition else { return }

        // Ignore if we haven't moved to a new cell
        guard position != head else { return }

        // If dragging back onto own path: truncate
        if path.contains(position) {
            truncatePath(color: color, to: position)
            return
        }

        // Must be adjacent to head
        guard head.isAdjacent(to: position) else { return }

        let cell = liveGrid[position.row][position.col]

        // Block if cell is occupied by a different path
        if case .path(let existing, _) = cell {
            if existing.color != color { return }
        }

        // Block if it's a different source terminal
        if case .terminal(let c, _, true, _) = cell, c != color { return }

        extendPath(color: color, to: position)
    }

    /// Called when the drag gesture ends.
    func dragEnded() {
        guard let color = activeDrawColor else { return }
        activeDrawColor = nil

        // Check if path has reached its target terminal
        if let path = activePaths[color], let head = path.headPosition {
            let cell = liveGrid[head.row][head.col]
            if case .terminal(let tc, let ts, false, _) = cell, tc == color {
                // Mark the target terminal with the arriving signal
                let arrivedSignal = path.currentSignal
                liveGrid[head.row][head.col] = .terminal(
                    color: tc,
                    signal: ts,
                    isSource: false,
                    arrivedSignal: arrivedSignal
                )
                activePaths[color]?.isComplete = true
            }
        }

        checkWinCondition()
    }

    // MARK: - Path Management

    private func startNewPath(color: NeonColor, signal: SignalState, at position: GridPosition) {
        // Clear any existing path of this color
        clearPath(color: color)

        let path = ActivePath(sourceColor: color, sourceSignal: signal, startPosition: position)
        activePaths[color] = path
        activeDrawColor = color
        // Source terminal stays as terminal (not replaced with a path segment)
    }

    private func extendPath(color: NeonColor, to position: GridPosition) {
        guard var path = activePaths[color],
              let prevHead = path.headPosition else { return }

        let cell = liveGrid[position.row][position.col]

        // Resolve gate transform if applicable
        let entryDir = prevHead.directionTo(position)
        let newSignal = applyGateTransform(cell: cell, incoming: path.currentSignal, entryDirection: entryDir)

        // If it's a target terminal — we don't replace it with a path cell
        if case .terminal = cell {
            path.segments.append(position)
            path.currentSignal = newSignal
            activePaths[color] = path
            return
        }

        // Determine path direction for rendering
        let prevPrevHead = path.segments.count >= 2 ? path.segments[path.segments.count - 2] : nil
        let prevEntryDir: GateDirection? = prevPrevHead.flatMap { $0.directionTo(prevHead) }
        let renderDir = PathDirection.from(entry: prevEntryDir, exit: entryDir)

        // Update previous head rendering direction
        if path.segments.count >= 1 {
            updatePathDirection(at: prevHead, entryDir: prevEntryDir, exitDir: entryDir, signal: path.currentSignal)
        }

        // Place path segment
        liveGrid[position.row][position.col] = .path(signal: newSignal, direction: renderDir)

        path.segments.append(position)
        path.currentSignal = newSignal
        activePaths[color] = path

        Haptics.playLightImpact()
    }

    private func truncatePath(color: NeonColor, to position: GridPosition) {
        guard var path = activePaths[color],
              let idx = path.indexOfSegment(position) else { return }

        // Clear all segment cells after this position
        let toRemove = Array(path.segments[(idx + 1)...])
        for pos in toRemove {
            let cell = liveGrid[pos.row][pos.col]
            // Don't clear terminals — restore them
            if case .terminal = cell { break }
            liveGrid[pos.row][pos.col] = .empty
        }

        // Also clear any arrived signal on a target terminal at the old head
        if let oldHead = path.headPosition {
            if case .terminal(let c, let s, false, _) = liveGrid[oldHead.row][oldHead.col] {
                liveGrid[oldHead.row][oldHead.col] = .terminal(color: c, signal: s, isSource: false, arrivedSignal: nil)
            }
        }

        path.segments = Array(path.segments.prefix(idx + 1))

        // Recompute current signal from scratch by replaying from source
        path.currentSignal = PathSignal(color: path.sourceColor, signal: path.sourceSignal)
        // (Full replay would be more accurate but segments store their resolved signals)
        if let lastSegPos = path.segments.last {
            if case .path(let s, _) = liveGrid[lastSegPos.row][lastSegPos.col] {
                path.currentSignal = s
            }
        }
        path.isComplete = false
        activePaths[color] = path
        activeDrawColor = color
    }

    private func clearPath(color: NeonColor) {
        guard let path = activePaths[color] else { return }
        for pos in path.segments {
            let cell = liveGrid[pos.row][pos.col]
            switch cell {
            case .path:
                liveGrid[pos.row][pos.col] = .empty
            case .terminal(let c, let s, let isSrc, _):
                // Reset arrived signal on the target terminal
                liveGrid[pos.row][pos.col] = .terminal(color: c, signal: s, isSource: isSrc, arrivedSignal: nil)
            case .gate(let t, _):
                liveGrid[pos.row][pos.col] = .gate(type: t, state: .idle)
            default:
                break
            }
        }
        activePaths.removeValue(forKey: color)
    }

    // MARK: - Gate Transform

    /// Computes the outgoing PathSignal after a signal passes through a cell (may be a gate).
    func applyGateTransform(cell: CellState, incoming: PathSignal, entryDirection: GateDirection?) -> PathSignal {
        switch cell {
        case .gate(let gateType, _):
            switch gateType {
            case .notGate(let constraint):
                let shouldInvert: Bool
                if let constraint = constraint, let entry = entryDirection {
                    shouldInvert = (constraint == entry)
                } else {
                    shouldInvert = true // unconstrained: always invert
                }
                if shouldInvert {
                    let flipped: SignalState = incoming.signal == .active ? .inactive : .active
                    return PathSignal(color: incoming.color, signal: flipped, wasTransformed: true)
                } else {
                    return incoming // constrained, wrong direction — pass through
                }

            case .colorShift(let outputColor):
                return PathSignal(color: outputColor, signal: incoming.signal, wasTransformed: true)

            case .bridge:
                // Bridge passes signals through without modification (crossing is handled by model, not transform)
                return incoming

            case .synthesizer(_, let outputColor, let outputSignal):
                // Synthesizer requires two inputs; single pass resolves based on gate logic
                // (Full Synthesizer state machine is handled in evaluateSynthesizer)
                return PathSignal(color: outputColor, signal: outputSignal, wasTransformed: true)
            }

        default:
            return incoming // Non-gate cell: pass through unchanged
        }
    }

    /// Updates the runtime state of a Synthesizer gate when a new input arrives.
    func evaluateSynthesizer(gateType: GateType, currentState: GateState, incoming: PathSignal) -> GateState {
        guard case .synthesizer(let logic, let outputColor, let outputSignal) = gateType else {
            return currentState
        }
        switch currentState {
        case .idle:
            return .partiallyFilled(arrivedInputs: [incoming])
        case .partiallyFilled(var inputs):
            inputs.append(incoming)
            // Synthesizer unlocks when it has received 2 inputs
            if inputs.count >= 2 {
                // Evaluate the boolean logic on signal states
                let activeCount = inputs.filter { $0.signal == .active }.count
                let shouldActivate: Bool
                switch logic {
                case .or:  shouldActivate = activeCount >= 1
                case .xor: shouldActivate = activeCount == 1
                }
                let resolvedSignal: SignalState = shouldActivate ? outputSignal : (outputSignal == .active ? .inactive : .active)
                return .active(outputColor: outputColor, outputSignal: resolvedSignal)
            }
            return .partiallyFilled(arrivedInputs: inputs)
        default:
            return currentState
        }
    }

    // MARK: - Win Condition

    func checkWinCondition() {
        guard allTerminalsPowered else { return }
        let stars = calculateStarRating()
        timerTask?.cancel()
        gameState = .completed(stars: stars)
        Haptics.playSuccess()
    }

    func calculateStarRating() -> Int {
        if isMaxEfficiency { return 3 }
        if isPerfectFlow { return 2 }
        return 1
    }

    // MARK: - Controls

    func resetLevel() {
        timerTask?.cancel()
        liveGrid = level.makeLiveGrid()
        activePaths = [:]
        activeDrawColor = nil
        gameState = .inProgress
        elapsedSeconds = 0
        startTimer()
    }

    /// Undoes the current path back to the last direction change (branch point).
    /// If the path is entirely straight, removes all segments back to the source.
    /// Falls back to removing a single segment if the path is very short.
    func undoToLastBranch() {
        guard let color = activeDrawColor ?? activePaths.first?.key else { return }
        guard var path = activePaths[color], path.segments.count > 1 else { return }

        // Find the index of the last direction change (turn) in the segment list.
        // A turn is any position where the direction from prev→current differs from current→next.
        var branchIndex: Int? = nil
        if path.segments.count >= 3 {
            for i in stride(from: path.segments.count - 2, through: 1, by: -1) {
                let prev = path.segments[i - 1]
                let curr = path.segments[i]
                let next = path.segments[i + 1]
                let dirIn  = prev.directionTo(curr)
                let dirOut = curr.directionTo(next)
                if dirIn != dirOut {
                    // This cell is a turn — undo back to here (exclusive)
                    branchIndex = i
                    break
                }
            }
        }

        // If no turn found (straight line) or path is < 3, undo to source (segment count 1)
        let targetLength = branchIndex ?? 1

        // Clear all cells after targetLength
        let toRemove = path.segments[targetLength...]
        for pos in toRemove {
            switch liveGrid[pos.row][pos.col] {
            case .path:
                liveGrid[pos.row][pos.col] = .empty
            case .terminal(let c, let s, false, _):
                // Reset arrived signal on any target terminal we're clearing
                liveGrid[pos.row][pos.col] = .terminal(color: c, signal: s, isSource: false, arrivedSignal: nil)
            case .gate(let t, _):
                liveGrid[pos.row][pos.col] = .gate(type: t, state: .idle)
            default:
                break
            }
        }

        path.segments = Array(path.segments.prefix(targetLength))
        path.isComplete = false

        // Recompute current signal from the new head
        if let headPos = path.segments.last {
            if case .path(let s, _) = liveGrid[headPos.row][headPos.col] {
                path.currentSignal = s
            } else {
                // Head is back at the source terminal
                path.currentSignal = PathSignal(color: path.sourceColor, signal: path.sourceSignal)
            }
        }

        activePaths[color] = path
        Haptics.playLightImpact()
    }

    // MARK: - Share String

    func generateShareString() -> String {
        let stars = calculateStarRating()
        let starStr = String(repeating: "★", count: stars) + String(repeating: "☆", count: 3 - stars)
        if isDaily {
            let dateStr = Date.now.formatted(.dateTime.day().month())
            return "Prisma Circuit · \(dateStr) \(starStr)"
        } else {
            return "Prisma Circuit · Level \(activeLevelId ?? 0) \(starStr)"
        }
    }

    // MARK: - Private Helpers

    private func isInBounds(_ pos: GridPosition) -> Bool {
        pos.row >= 0 && pos.row < level.size && pos.col >= 0 && pos.col < level.size
    }

    private func colorOfPath(at position: GridPosition) -> NeonColor? {
        activePaths.first { $0.value.contains(position) }?.key
    }

    private func updatePathDirection(at pos: GridPosition, entryDir: GateDirection?, exitDir: GateDirection?, signal: PathSignal) {
        guard case .path = liveGrid[pos.row][pos.col] else { return }
        let dir = PathDirection.from(entry: entryDir, exit: exitDir)
        liveGrid[pos.row][pos.col] = .path(signal: signal, direction: dir)
    }

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { break }
                self.elapsedSeconds += 1
            }
        }
    }
}
