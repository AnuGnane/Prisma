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
//  Architecture — pathLayer separation:
//  ──────────────────────────────────────
//  `liveGrid` is the *static* layer. It holds terminals, gates, and waypoints
//  exactly as loaded from the level. Path drawing NEVER replaces cells in
//  liveGrid — only gate runtime state, waypoint visited flags, and terminal
//  arrivedSignal are mutated here.
//
//  `pathLayer` is the *dynamic* drawing layer. It maps every grid position the
//  player has drawn over to the PathSignal at that position. CircuitCanvasView
//  reads from pathLayer for rendering. clearPath / truncatePath remove entries;
//  extendPath adds them. This prevents path drawing from destroying gate or
//  waypoint cells, which was the root cause of the core gameplay bugs.
//

import Foundation
import Observation

// MARK: - Game State

enum CircuitGameState: Equatable {
    case inProgress
    case completed(stars: Int)
    case gaveUp
}

// MARK: - ViewModel

@Observable @MainActor
final class CircuitGameViewModel: PrismaGameViewModel {

    // MARK: - Configuration

    let isDaily: Bool
    let activeLevelId: Int?

    // MARK: - Level Data

    private(set) var level: CircuitLevel

    // MARK: - Static Grid

    /// The mutable-but-stable grid holding level entities (terminals, gates, waypoints).
    /// Only gate runtime state, waypoint.visited, and terminal arrivedSignal change
    /// during gameplay — the cell type itself is never replaced by a path cell.
    private(set) var liveGrid: [[CellState]]

    // MARK: - Path Layer

    /// Maps every position the player has drawn on to the PathSignal at that cell.
    /// CircuitCanvasView reads from this for per-segment color/signal rendering.
    private(set) var pathLayer: [GridPosition: PathSignal] = [:]

    // MARK: - Active Paths

    /// One active path per NeonColor (at most one path per color simultaneously).
    private(set) var activePaths: [NeonColor: ActivePath] = [:]

    /// The order in which the player has drawn each color, earliest-first.
    /// This is persisted alongside `activePaths` because dictionary ordering
    /// is non-deterministic and Synthesizer-bearing boards replay differently
    /// depending on which color arrives first.
    private(set) var drawnColorOrder: [NeonColor] = []

    /// The color currently being drawn (nil when no drag is in progress).
    private(set) var activeDrawColor: NeonColor? = nil

    // MARK: - Game State

    private(set) var gameState: CircuitGameState = .inProgress

    // MARK: - Solution View

    private(set) var showingSolution = false

    // MARK: - Timer

    private(set) var elapsedSeconds: Double = 0
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

    /// Number of cells covered by player-drawn path segments.
    var filledPathCells: Int { pathLayer.count }

    /// Total occupied cells: the union of path-drawn positions and static entities
    /// (terminals, gates, waypoints). Avoids double-counting when a path passes
    /// through a gate or waypoint.
    var usedCells: Int {
        var positions = Set(pathLayer.keys)
        for row in 0..<level.size {
            for col in 0..<level.size {
                if !liveGrid[row][col].isEmpty {
                    positions.insert(GridPosition(row, col))
                }
            }
        }
        return positions.count
    }

    var coveragePercent: Double {
        Double(usedCells) / Double(totalCells)
    }

    var totalPathLength: Int {
        activePaths.values.reduce(0) { $0 + $1.length }
    }

    var validTerminalPairs: [TerminalPair] {
        level.terminalPairs.filter { pair in
            guard pair.target.row >= 0,
                  pair.target.col >= 0,
                  pair.target.row < level.size,
                  pair.target.col < level.size else {
                return false
            }

            guard case .terminal(_, _, false, _) = liveGrid[pair.target.row][pair.target.col] else {
                return false
            }

            return true
        }
    }

    var poweredTerminalCount: Int {
        validTerminalPairs.filter { pair in
            guard case .terminal(let c, let s, false, let arrived) = liveGrid[pair.target.row][pair.target.col],
                  let a = arrived else { return false }
            return a.color == c && a.signal == s
        }.count
    }

    var allTerminalsPowered: Bool {
        poweredTerminalCount == validTerminalPairs.count
    }

    /// True when all waypoints in the level have been visited by a drawn path.
    var allWaypointsVisited: Bool {
        let totalWaypoints = liveGrid.flatMap { $0 }.filter { $0.isWaypoint }.count
        guard totalWaypoints > 0 else { return true }
        let visited = liveGrid.flatMap { $0 }.filter { $0.waypointVisited }.count
        return visited == totalWaypoints
    }

    var isPerfectFlow: Bool {
        allTerminalsPowered && allWaypointsVisited && coveragePercent >= 1.0
    }

    var isMaxEfficiency: Bool {
        allTerminalsPowered && allWaypointsVisited
    }

    var isGameOver: Bool {
        if case .completed = gameState { return true }
        if case .gaveUp = gameState { return true }
        return false
    }

    // MARK: - Timer UI

    var timerString: String {
        let totalSeconds = Int(elapsedSeconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
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
            // Starting from a source terminal — clear existing path and begin fresh.
            startNewPath(color: color, signal: signal, at: position)
        default:
            // Check pathLayer: player may be tapping on an existing drawn path
            // (which no longer shows as .path in liveGrid with the new architecture).
            if let color = colorOfPath(at: position) {
                truncatePath(color: color, to: position)
                activeDrawColor = color
            }
        }
    }

    /// Called as the drag moves to a new grid position.
    func dragMoved(to position: GridPosition) {
        guard !isGameOver else { return }
        guard let color = activeDrawColor else { return }
        guard isInBounds(position) else { return }
        guard let path = activePaths[color] else { return }
        guard let head = path.headPosition else { return }

        // Once a path reaches any target terminal, it cannot be extended past that endpoint.
        if case .terminal(_, _, false, _) = liveGrid[head.row][head.col] {
            return
        }

        // Ignore if we haven't moved to a new cell.
        guard position != head else { return }

        // If dragging back onto own path: truncate to that point.
        if path.contains(position) {
            truncatePath(color: color, to: position)
            return
        }

        // Must be adjacent to head.
        guard head.isAdjacent(to: position) else { return }

        let cell = liveGrid[position.row][position.col]

        // Block if cell is already owned by a different path in pathLayer.
        if pathLayer[position] != nil {
            if let existingColor = colorOfPath(at: position), existingColor != color {
                if !canShareCellWithOtherPath(cell) {
                    return
                }
            }
        }

        // Block entry into a different color's source terminal.
        if case .terminal(let c, _, true, _) = cell, c != color { return }

        extendPath(color: color, to: position)
    }

    /// Called when the drag gesture ends.
    func dragEnded() {
        guard let color = activeDrawColor else { return }
        activeDrawColor = nil

        finalizeArrivalForPath(color: color)

        checkWinCondition()
    }

    private func finalizeArrivalForPath(color: NeonColor) {
        guard let path = activePaths[color], let head = path.headPosition else { return }

        let cell = liveGrid[head.row][head.col]
        guard case .terminal(let tc, let ts, false, _) = cell else { return }

        let arrivedSignal = path.currentSignal
        liveGrid[head.row][head.col] = .terminal(
            color: tc,
            signal: ts,
            isSource: false,
            arrivedSignal: arrivedSignal
        )
        activePaths[color]?.isComplete = (arrivedSignal.color == tc && arrivedSignal.signal == ts)
    }

    // MARK: - Path Management

    private func startNewPath(color: NeonColor, signal: SignalState, at position: GridPosition) {
        // Clear any existing path of this color before starting fresh.
        // clearPath already removes the old entry from drawnColorOrder so the
        // re-drawn path appears last in the order list (matches user intent:
        // "the most recently started color is the freshest").
        clearPath(color: color)
        let path = ActivePath(sourceColor: color, sourceSignal: signal, startPosition: position)
        activePaths[color] = path
        drawnColorOrder.append(color)
        activeDrawColor = color
        // Source terminal is NOT added to pathLayer — it remains a static entity in liveGrid.
    }

    private func extendPath(color: NeonColor, to position: GridPosition) {
        guard var path = activePaths[color],
              let prevHead = path.headPosition else { return }

        let cell = liveGrid[position.row][position.col]
        let entryDir = prevHead.directionTo(position)
        var newSignal = applyGateTransform(cell: cell, incoming: path.currentSignal, entryDirection: entryDir)

        // Update runtime state on static entities in liveGrid WITHOUT replacing the cell type.
        switch cell {
        case .gate(let gateType, let gateState):
            let newGateState: GateState
            switch gateType {
            case .synthesizer:
                // Synthesizer state is updated before transform so the second
                // arriving path can immediately receive the mixed output.
                newGateState = evaluateSynthesizer(
                    gateType: gateType,
                    currentState: gateState,
                    incoming: path.currentSignal
                )
                let updatedCell = CellState.gate(type: gateType, state: newGateState)
                newSignal = applyGateTransform(cell: updatedCell, incoming: path.currentSignal, entryDirection: entryDir)
            case .bridge:
                // Track which axis this path is crossing. Each axis is independent.
                let isHorizontal = entryDir?.isHorizontal ?? true
                if case .bridgeLocked(let h, let v) = gateState {
                    newGateState = isHorizontal
                        ? .bridgeLocked(horizontalSignal: path.currentSignal, verticalSignal: v)
                        : .bridgeLocked(horizontalSignal: h, verticalSignal: path.currentSignal)
                } else {
                    newGateState = isHorizontal
                        ? .bridgeLocked(horizontalSignal: path.currentSignal, verticalSignal: nil)
                        : .bridgeLocked(horizontalSignal: nil, verticalSignal: path.currentSignal)
                }
            default:
                newGateState = .active(outputColor: newSignal.color, outputSignal: newSignal.signal)
            }
            liveGrid[position.row][position.col] = .gate(type: gateType, state: newGateState)

        case .waypoint:
            // Mark waypoint as visited (needed for win condition check).
            liveGrid[position.row][position.col] = .waypoint(visited: true)

        case .terminal(let tc, let ts, false, _):
            // Eagerly record arriving signal on the target terminal so wrong-state
            // arrivals are visible to the player.
            liveGrid[position.row][position.col] = .terminal(
                color: tc, signal: ts, isSource: false,
                arrivedSignal: newSignal
            )
            path.isComplete = (newSignal.color == tc && newSignal.signal == ts)

        default:
            break
        }

        // Record signal in pathLayer — never write .path(...) to liveGrid.
        pathLayer[position] = newSignal
        path.segments.append(position)
        path.currentSignal = newSignal
        activePaths[color] = path

        Haptics.playLightImpact()
    }

    private func truncatePath(color: NeonColor, to position: GridPosition) {
        guard var path = activePaths[color],
              let idx = path.indexOfSegment(position) else { return }

        // Remove all positions after the truncation point from pathLayer and
        // restore the underlying static entity state.
        let toRemove = Array(path.segments[(idx + 1)...])
        for pos in toRemove {
            if !isOccupiedByOtherPath(position: pos, excluding: color) {
                pathLayer.removeValue(forKey: pos)
                resetStaticCell(at: pos)
            }
        }

        // Also reset the arrived signal on the old head if it was a target terminal.
        if let oldHead = path.headPosition,
           !isOccupiedByOtherPath(position: oldHead, excluding: color),
           case .terminal(let c, let s, false, _) = liveGrid[oldHead.row][oldHead.col] {
            liveGrid[oldHead.row][oldHead.col] = .terminal(color: c, signal: s, isSource: false, arrivedSignal: nil)
        }

        path.segments = Array(path.segments.prefix(idx + 1))
        path.isComplete = false

        // Restore current signal from pathLayer at the new head (gate-transformed value).
        if let headPos = path.segments.last, let signal = pathLayer[headPos] {
            path.currentSignal = signal
        } else {
            // Head has been truncated all the way back to the source terminal.
            path.currentSignal = PathSignal(color: path.sourceColor, signal: path.sourceSignal)
        }

        activePaths[color] = path
        activeDrawColor = color
    }

    private func clearPath(color: NeonColor) {
        guard let path = activePaths[color] else { return }
        for pos in path.segments {
            if !isOccupiedByOtherPath(position: pos, excluding: color) {
                pathLayer.removeValue(forKey: pos)
                resetStaticCell(at: pos)
            }
        }
        activePaths.removeValue(forKey: color)
        drawnColorOrder.removeAll { $0 == color }
    }

    /// Restores the runtime state of a static entity after its overlying path is removed.
    private func resetStaticCell(at pos: GridPosition) {
        switch liveGrid[pos.row][pos.col] {
        case .gate(let t, _):
            liveGrid[pos.row][pos.col] = .gate(type: t, state: initialGateState(for: t))
        case .waypoint:
            liveGrid[pos.row][pos.col] = .waypoint(visited: false)
        case .terminal(let c, let s, let isSrc, _):
            liveGrid[pos.row][pos.col] = .terminal(color: c, signal: s, isSource: isSrc, arrivedSignal: nil)
        default:
            break
        }
    }

    private func initialGateState(for gateType: GateType) -> GateState {
        switch gateType {
        case .bridge: return .bridgeLocked(horizontalSignal: nil, verticalSignal: nil)
        default:      return .idle
        }
    }

    // MARK: - Gate Transform

    /// Computes the outgoing PathSignal after a signal passes through a cell (which may be a gate).
    func applyGateTransform(cell: CellState, incoming: PathSignal, entryDirection: GateDirection?) -> PathSignal {
        switch cell {
        case .gate(let gateType, _):
            switch gateType {
            case .notGate(let constraint):
                let shouldInvert: Bool
                if let constraint = constraint, let entry = entryDirection {
                    shouldInvert = (constraint == entry)
                } else {
                    shouldInvert = true // Unconstrained NOT gate: always inverts.
                }
                if shouldInvert {
                    let flipped: SignalState = incoming.signal == .active ? .inactive : .active
                    return PathSignal(color: incoming.color, signal: flipped, wasTransformed: true)
                } else {
                    return incoming // Wrong direction for a constrained gate: pass through.
                }

            case .bridge:
                // Bridge passes the signal through on the entering axis without modification.
                return incoming

            case .synthesizer:
                if case .gate(_, let state) = cell,
                   case .active(let outputColor, let outputSignal) = state {
                    return PathSignal(color: outputColor, signal: outputSignal, wasTransformed: true)
                }
                // Gate not fully resolved yet — pass signal through until both
                // synthesizer inputs arrive and activate its mixed output.
                return incoming
            }

        default:
            return incoming // Non-gate cell: pass signal through unchanged.
        }
    }

    /// Updates the runtime state of a Synthesizer gate when a new input arrives.
    func evaluateSynthesizer(gateType: GateType, currentState: GateState, incoming: PathSignal) -> GateState {
        guard case .synthesizer(let logic, let outputSignal) = gateType else {
            return currentState
        }
        switch currentState {
        case .idle:
            return .partiallyFilled(arrivedInputs: [incoming])
        case .partiallyFilled(var inputs):
            inputs.append(incoming)
            if inputs.count >= 2 {
                let lhs = inputs[inputs.count - 2]
                let rhs = inputs[inputs.count - 1]
                let mixedColor = lhs.color.mixed(with: rhs.color)
                let activeCount = [lhs, rhs].filter { $0.signal == .active }.count
                let shouldActivate: Bool
                switch logic {
                case .or:  shouldActivate = activeCount >= 1
                case .xor: shouldActivate = activeCount == 1
                }
                let resolvedSignal: SignalState = shouldActivate
                    ? outputSignal
                    : (outputSignal == .active ? .inactive : .active)
                return .active(outputColor: mixedColor, outputSignal: resolvedSignal)
            }
            return .partiallyFilled(arrivedInputs: inputs)
        default:
            return currentState
        }
    }

    // MARK: - Win Condition

    func checkWinCondition() {
        // Completion baseline is all targets powered + all waypoints visited.
        guard allTerminalsPowered && allWaypointsVisited else { return }
        
        forceFinish()
    }
    
    /// Finishes the game early when the user settles for a sub-optimal solution.
    func forceFinish() {
        guard allTerminalsPowered && allWaypointsVisited else { return }
        let stars = calculateStarRating()
        timerTask?.cancel()
        gameState = .completed(stars: stars)
        Haptics.playSuccess()
    }

    func calculateStarRating() -> Int {
        guard allTerminalsPowered && allWaypointsVisited else { return 0 }
        
        let coverage = Double(usedCells) / Double(totalCells)
        
        if coverage >= 1.0 { return 3 } // 100% board coverage
        if coverage >= 0.8 { return 2 } // 80%+ board coverage
        return 1 // Completion only
    }

    // MARK: - Give Up

    func giveUp() {
        guard gameState == .inProgress else { return }
        timerTask?.cancel()
        gameState = .gaveUp
    }

    func showSolution() { showingSolution = true }
    func hideSolution() { showingSolution = false }

    // MARK: - Result Builder

    /// Builds a persisted result payload from the current completed state.
    func buildGameResult() -> GameResult {
        let stars: Int
        if case .completed(let s) = gameState {
            stars = s
        } else {
            stars = 0
        }

        // Circuit uses star rating for local progression while leaderboard scoring
        // continues to use duration inside ScoreManager's Circuit branch.
        let persistedScore = stars * 100

        return GameResult(
            gameType: .circuit,
            date: .now,
            score: persistedScore,
            shareString: generateShareString(),
            guessCount: totalPathLength,
            isDaily: isDaily,
            durationSeconds: Double(elapsedSeconds),
            levelId: activeLevelId,
            circuitStateJSON: CircuitStateSerializer.serialize(
                activePaths: activePaths,
                pathOrder: drawnColorOrder
            )
        )
    }

    // MARK: - Controls

    func reset() {
        timerTask?.cancel()
        liveGrid = level.makeLiveGrid()
        pathLayer = [:]
        activePaths = [:]
        drawnColorOrder = []
        activeDrawColor = nil
        gameState = .inProgress
        showingSolution = false
        elapsedSeconds = 0
        startTimer()
    }

    /// Undoes the current path back to the last direction change (branch point).
    /// If the path is entirely straight, reverts all the way to the source.
    func undoToLastBranch() {
        guard let color = activeDrawColor ?? activePaths.first?.key else { return }
        guard var path = activePaths[color], path.segments.count > 1 else { return }

        var branchIndex: Int? = nil
        if path.segments.count >= 3 {
            for i in stride(from: path.segments.count - 2, through: 1, by: -1) {
                let prev = path.segments[i - 1]
                let curr = path.segments[i]
                let next = path.segments[i + 1]
                let dirIn  = prev.directionTo(curr)
                let dirOut = curr.directionTo(next)
                if dirIn != dirOut {
                    branchIndex = i
                    break
                }
            }
        }

        let targetLength = branchIndex ?? 1
        let toRemove = path.segments[targetLength...]
        for pos in toRemove {
            if !isOccupiedByOtherPath(position: pos, excluding: color) {
                pathLayer.removeValue(forKey: pos)
                resetStaticCell(at: pos)
            }
        }

        path.segments = Array(path.segments.prefix(targetLength))
        path.isComplete = false

        if let headPos = path.segments.last, let signal = pathLayer[headPos] {
            path.currentSignal = signal
        } else {
            path.currentSignal = PathSignal(color: path.sourceColor, signal: path.sourceSignal)
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

    // MARK: - State Restoration

    /// Restores the visual board state from serialized active paths.
    /// This replays the stored drawing actions so the board's gate and
    /// logic state evaluates identically to what the user actually played.
    ///
    /// Preferred path: honour `state.pathOrder` verbatim. It is the exact
    /// draw order the player used, so the replay is guaranteed to match the
    /// original game (including Synthesizer arrival ordering).
    ///
    /// Fallback paths exist for:
    ///   - legacy saves that predate `pathOrder` (nil),
    ///   - canonical solution payloads that omit `pathOrder`,
    ///   - corrupted orders that don't resolve to a winning state.
    func restoreState(from state: CircuitState) {
        timerTask?.cancel()

        guard !state.activePaths.isEmpty else {
            resetRuntimeStateForRestore()
            return
        }

        // 1) Preferred: replay exactly as recorded. Do not second-guess the
        //    user's own drawing — a non-winning save (give-up, partial play)
        //    must still render exactly what they left behind.
        if let order = state.pathOrder, !order.isEmpty {
            let orderedPaths: [ActivePath] = order.compactMap { state.activePaths[$0] }
            // Append any paths missing from the order list (shouldn't happen,
            // but guard against corrupted saves).
            let missing = state.activePaths.values.filter { p in
                !order.contains(p.sourceColor)
            }
            let fullOrder = orderedPaths + missing
            _ = attemptRestore(fullOrder)
            return
        }

        // 2) Legacy / canonical-solution path: attempt dict order, then
        //    permutations to find a winning replay (synth-sensitive).
        let candidatePaths = Array(state.activePaths.values)

        if attemptRestore(candidatePaths) {
            return
        }

        if candidatePaths.count > 1 && candidatePaths.count <= 6 {
            var used = Array(repeating: false, count: candidatePaths.count)
            var order: [ActivePath] = []
            if findRestorableOrder(candidatePaths, used: &used, order: &order) {
                return
            }
        }

        let deterministicOrder = candidatePaths.sorted { lhs, rhs in
            lhs.sourceColor.rawValue < rhs.sourceColor.rawValue
        }
        _ = attemptRestore(deterministicOrder)
    }

    private func resetRuntimeStateForRestore() {
        liveGrid = level.makeLiveGrid()
        pathLayer = [:]
        activePaths = [:]
        drawnColorOrder = []
        activeDrawColor = nil
    }

    private func attemptRestore(_ orderedPaths: [ActivePath]) -> Bool {
        resetRuntimeStateForRestore()

        for path in orderedPaths {
            replayRestoredPath(path)
        }

        activeDrawColor = nil
        return allTerminalsPowered && allWaypointsVisited
    }

    private func replayRestoredPath(_ path: ActivePath) {
        guard let first = path.segments.first, isInBounds(first) else { return }

        startNewPath(color: path.sourceColor, signal: path.sourceSignal, at: first)
        for pos in path.segments.dropFirst() {
            guard isInBounds(pos) else { break }
            extendPath(color: path.sourceColor, to: pos)
        }
        finalizeArrivalForPath(color: path.sourceColor)
    }

    private func findRestorableOrder(_ candidates: [ActivePath], used: inout [Bool], order: inout [ActivePath]) -> Bool {
        if order.count == candidates.count {
            return attemptRestore(order)
        }

        for idx in candidates.indices {
            if used[idx] { continue }
            used[idx] = true
            order.append(candidates[idx])

            if findRestorableOrder(candidates, used: &used, order: &order) {
                return true
            }

            order.removeLast()
            used[idx] = false
        }

        return false
    }

    // MARK: - Private Helpers

    private func isInBounds(_ pos: GridPosition) -> Bool {
        pos.row >= 0 && pos.row < level.size && pos.col >= 0 && pos.col < level.size
    }

    /// Returns the color of whichever active path occupies `position` in the pathLayer.
    private func colorOfPath(at position: GridPosition) -> NeonColor? {
        guard pathLayer[position] != nil else { return nil }
        return activePaths.first { $0.value.contains(position) }?.key
    }

    private func canShareCellWithOtherPath(_ cell: CellState) -> Bool {
        guard case .gate(let gateType, _) = cell else { return false }
        switch gateType {
        case .bridge, .synthesizer:
            return true
        default:
            return false
        }
    }

    private func isOccupiedByOtherPath(position: GridPosition, excluding color: NeonColor) -> Bool {
        activePaths.contains { key, path in
            key != color && path.contains(position)
        }
    }

    private func startTimer() {
        timerTask = Task { [weak self] in
            let start = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { break }
                self.elapsedSeconds = Date().timeIntervalSince(start)
            }
        }
    }
}
