//
//  CircuitGameTests.swift
//  PrismaTests
//
//  Tests for the Circuit mini-game: gate transforms, color mixing,
//  terminal validation, win conditions, star ratings, serialization,
//  and level data integrity.
//

import Foundation
import Testing
@testable import Prisma

// MARK: - Color Mixing

struct CircuitColorMixingTests {
    @Test func blueAndRedMakePurple() {
        #expect(NeonColor.blue.mixed(with: .red) == .purple)
    }

    @Test func redAndYellowMakeOrange() {
        #expect(NeonColor.red.mixed(with: .yellow) == .orange)
    }

    @Test func blueAndYellowMakeGreen() {
        #expect(NeonColor.blue.mixed(with: .yellow) == .green)
    }

    @Test func sameColorReturnsSame() {
        #expect(NeonColor.blue.mixed(with: .blue) == .blue)
        #expect(NeonColor.red.mixed(with: .red) == .red)
        #expect(NeonColor.yellow.mixed(with: .yellow) == .yellow)
    }

    @Test func mixingIsCommutative() {
        #expect(NeonColor.blue.mixed(with: .red) == NeonColor.red.mixed(with: .blue))
        #expect(NeonColor.red.mixed(with: .yellow) == NeonColor.yellow.mixed(with: .red))
        #expect(NeonColor.blue.mixed(with: .yellow) == NeonColor.yellow.mixed(with: .blue))
    }

    @Test func secondaryMixWithPrimaryReturnsSecondary() {
        #expect(NeonColor.purple.mixed(with: .blue) == .purple)
        #expect(NeonColor.orange.mixed(with: .red) == .orange)
    }

    /// Tertiary mixes (all three primaries) are intentionally unsupported.
    /// Any level author who relies on green+orange → red (etc.) is building
    /// an unwinnable puzzle — this test documents that contract explicitly
    /// so it can't regress silently.
    @Test func tertiaryMixesReturnReceiver() {
        // Every unordered pair of secondaries spans all three primary channels.
        #expect(NeonColor.green.mixed(with: .orange) == .green)
        #expect(NeonColor.orange.mixed(with: .green) == .orange)
        #expect(NeonColor.green.mixed(with: .purple) == .green)
        #expect(NeonColor.purple.mixed(with: .green) == .purple)
        #expect(NeonColor.orange.mixed(with: .purple) == .orange)
        #expect(NeonColor.purple.mixed(with: .orange) == .purple)
    }

    /// Cross-primary mixing a secondary with the one primary it doesn't
    /// already contain also produces a tertiary — must return receiver.
    @Test func secondaryMixWithMissingPrimaryReturnsReceiver() {
        // green = blue + yellow; + red → tertiary → receiver.
        #expect(NeonColor.green.mixed(with: .red) == .green)
        // orange = red + yellow; + blue → tertiary → receiver.
        #expect(NeonColor.orange.mixed(with: .blue) == .orange)
        // purple = blue + red; + yellow → tertiary → receiver.
        #expect(NeonColor.purple.mixed(with: .yellow) == .purple)
    }
}

// MARK: - Gate Transforms

struct CircuitGateTransformTests {

    @Test func notGateUnconstrainedInvertsSignal() {
        let gate = CellState.gate(type: .notGate(direction: nil), state: .idle)
        let incoming = PathSignal(color: .blue, signal: .active)

        let result = applyTransform(gate, incoming, entry: .leftToRight)

        #expect(result.signal == .inactive)
        #expect(result.color == .blue)
        #expect(result.wasTransformed)
    }

    @Test func notGateCorrectDirectionInverts() {
        let gate = CellState.gate(type: .notGate(direction: .leftToRight), state: .idle)
        let incoming = PathSignal(color: .red, signal: .active)

        let result = applyTransform(gate, incoming, entry: .leftToRight)

        #expect(result.signal == .inactive)
        #expect(result.wasTransformed)
    }

    @Test func notGateWrongDirectionPassesThrough() {
        let gate = CellState.gate(type: .notGate(direction: .leftToRight), state: .idle)
        let incoming = PathSignal(color: .red, signal: .active)

        let result = applyTransform(gate, incoming, entry: .topToBottom)

        #expect(result.signal == .active)
        #expect(result.wasTransformed == false)
    }

    @Test func notGateInvertsInactiveToActive() {
        let gate = CellState.gate(type: .notGate(direction: nil), state: .idle)
        let incoming = PathSignal(color: .yellow, signal: .inactive)

        let result = applyTransform(gate, incoming, entry: .leftToRight)

        #expect(result.signal == .active)
    }

    @Test func bridgePassesThroughUnchanged() {
        let gate = CellState.gate(type: .bridge, state: .bridgeLocked(horizontalSignal: nil, verticalSignal: nil))
        let incoming = PathSignal(color: .blue, signal: .active)

        let result = applyTransform(gate, incoming, entry: .leftToRight)

        #expect(result.color == .blue)
        #expect(result.signal == .active)
        #expect(result.wasTransformed == false)
    }

    @Test func emptyCellPassesThroughUnchanged() {
        let incoming = PathSignal(color: .red, signal: .inactive)
        let result = applyTransform(.empty, incoming, entry: .topToBottom)

        #expect(result.color == .red)
        #expect(result.signal == .inactive)
    }

    /// Mirrors CircuitGameViewModel.applyGateTransform logic for standalone testing
    private func applyTransform(_ cell: CellState, _ incoming: PathSignal, entry: GateDirection?) -> PathSignal {
        switch cell {
        case .gate(let gateType, _):
            switch gateType {
            case .notGate(let constraint):
                let shouldInvert: Bool
                if let constraint, let entry {
                    shouldInvert = (constraint == entry)
                } else {
                    shouldInvert = true
                }
                if shouldInvert {
                    let flipped: SignalState = incoming.signal == .active ? .inactive : .active
                    return PathSignal(color: incoming.color, signal: flipped, wasTransformed: true)
                }
                return incoming
            case .bridge:
                return incoming
            case .synthesizer:
                if case .gate(_, let state) = cell,
                   case .active(let outColor, let outSignal) = state {
                    return PathSignal(color: outColor, signal: outSignal, wasTransformed: true)
                }
                return incoming
            }
        default:
            return incoming
        }
    }
}

// MARK: - Synthesizer Logic

@MainActor
struct CircuitSynthesizerTests {

    @Test func synthesizerIdleToPartiallyFilled() {
        let vm = CircuitGameViewModel(levelId: 1)
        let gateType = GateType.synthesizer(logic: .or, outputSignal: .active)
        let incoming = PathSignal(color: .blue, signal: .active)

        let result = vm.evaluateSynthesizer(gateType: gateType, currentState: .idle, incoming: incoming)

        if case .partiallyFilled(let inputs) = result {
            #expect(inputs.count == 1)
            #expect(inputs[0].color == .blue)
        } else {
            Issue.record("Expected partiallyFilled state, got \(result)")
        }
    }

    @Test func synthesizerTwoInputsActivatesOR() {
        let vm = CircuitGameViewModel(levelId: 1)
        let gateType = GateType.synthesizer(logic: .or, outputSignal: .active)
        let first = PathSignal(color: .blue, signal: .active)
        let second = PathSignal(color: .red, signal: .inactive)

        let partial = vm.evaluateSynthesizer(gateType: gateType, currentState: .idle, incoming: first)
        let result = vm.evaluateSynthesizer(gateType: gateType, currentState: partial, incoming: second)

        if case .active(let color, let signal) = result {
            #expect(color == .purple) // blue + red = purple
            #expect(signal == .active) // OR: at least one active
        } else {
            Issue.record("Expected active state, got \(result)")
        }
    }

    @Test func synthesizerXORWithBothActiveInverts() {
        let vm = CircuitGameViewModel(levelId: 1)
        let gateType = GateType.synthesizer(logic: .xor, outputSignal: .active)
        let first = PathSignal(color: .red, signal: .active)
        let second = PathSignal(color: .yellow, signal: .active)

        let partial = vm.evaluateSynthesizer(gateType: gateType, currentState: .idle, incoming: first)
        let result = vm.evaluateSynthesizer(gateType: gateType, currentState: partial, incoming: second)

        if case .active(let color, let signal) = result {
            #expect(color == .orange) // red + yellow = orange
            #expect(signal == .inactive) // XOR: both active → not exactly one → inverted
        } else {
            Issue.record("Expected active state, got \(result)")
        }
    }
}

// MARK: - Serialization

struct CircuitSerializationTests {

    @Test func serializationRoundTrip() throws {
        var path = ActivePath(sourceColor: .blue, sourceSignal: .active, startPosition: GridPosition(0, 0))
        path.segments = [GridPosition(0, 0), GridPosition(0, 1), GridPosition(0, 2)]
        path.currentSignal = PathSignal(color: .blue, signal: .active)
        path.isComplete = true

        let paths: [NeonColor: ActivePath] = [.blue: path]
        let json = try #require(CircuitStateSerializer.serialize(activePaths: paths))
        let restored = try #require(CircuitStateSerializer.deserialize(json))

        let restoredPath = try #require(restored.activePaths[.blue])
        #expect(restoredPath.sourceColor == .blue)
        #expect(restoredPath.sourceSignal == .active)
        #expect(restoredPath.segments.count == 3)
        #expect(restoredPath.isComplete)
    }

    @Test func legacyColorDecoding() throws {
        let json = """
        {"activePaths":{"cyan":{"sourceColor":"cyan","sourceSignal":"active","segments":[{"row":0,"col":0}],"currentSignal":{"color":"cyan","signal":"active","wasTransformed":false},"isComplete":true}}}
        """
        let state = try #require(CircuitStateSerializer.deserialize(json))
        let path = try #require(state.activePaths[.blue]) // cyan maps to blue
        #expect(path.sourceColor == .blue)
        #expect(path.currentSignal.color == .blue)
        // Legacy saves pre-date `pathOrder` — must decode as nil, not empty.
        #expect(state.pathOrder == nil)
    }

    /// `pathOrder` must round-trip verbatim so Synthesizer-bearing saves
    /// can be replayed in the exact draw order the player used.
    @Test func pathOrderRoundTrip() throws {
        var blue = ActivePath(sourceColor: .blue, sourceSignal: .active, startPosition: GridPosition(0, 0))
        blue.segments = [GridPosition(0, 0), GridPosition(0, 1)]

        var red = ActivePath(sourceColor: .red, sourceSignal: .active, startPosition: GridPosition(1, 0))
        red.segments = [GridPosition(1, 0), GridPosition(1, 1)]

        let paths: [NeonColor: ActivePath] = [.blue: blue, .red: red]
        let order: [NeonColor] = [.red, .blue] // deliberately not alphabetical

        let json = try #require(CircuitStateSerializer.serialize(activePaths: paths, pathOrder: order))
        let restored = try #require(CircuitStateSerializer.deserialize(json))

        #expect(restored.pathOrder == [.red, .blue])
        #expect(restored.activePaths.count == 2)
    }

    /// A corrupted `pathOrder` containing a color with no matching path must
    /// be silently filtered so we never get "ghost" entries in the replay.
    @Test func corruptedPathOrderFiltersGhosts() throws {
        var blue = ActivePath(sourceColor: .blue, sourceSignal: .active, startPosition: GridPosition(0, 0))
        blue.segments = [GridPosition(0, 0)]

        let json = """
        {"activePaths":{"blue":\(try activePathJSON(blue))},"pathOrder":["yellow","blue","purple"]}
        """
        let restored = try #require(CircuitStateSerializer.deserialize(json))

        #expect(restored.pathOrder == [.blue])
    }

    private func activePathJSON(_ path: ActivePath) throws -> String {
        let data = try JSONEncoder().encode(path)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Level Loader Integrity

struct CircuitLevelLoaderTests {

    @Test func allCuratedLevelsLoad() {
        let levels = CircuitLevelLoader.load()
        #expect(levels.count >= 10)
    }

    @Test func allLevelsHaveTerminalPairs() {
        let levels = CircuitLevelLoader.load()
        for level in levels {
            #expect(level.terminalPairs.isEmpty == false, "Level \(level.id) has no terminal pairs")
        }
    }

    /// Every curated level must declare its targets with the exact color/signal
    /// that the target cell itself advertises. A mismatch here meant the
    /// original L6/L10 displayed inconsistent colors in the UI vs. the
    /// win-check path. This test catches that class of regression.
    @Test func terminalPairColorMatchesTargetCell() {
        let levels = CircuitLevelLoader.load()
        for level in levels {
            for pair in level.terminalPairs {
                guard pair.target.row >= 0,
                      pair.target.col >= 0,
                      pair.target.row < level.size,
                      pair.target.col < level.size else { continue }

                let cellData = level.grid[pair.target.row][pair.target.col]
                guard cellData.kind == .target else { continue }

                #expect(
                    cellData.color == pair.color,
                    "Level \(level.id) pair at (\(pair.target.row),\(pair.target.col)) declares color \(pair.color) but target cell is \(String(describing: cellData.color))"
                )
                #expect(
                    cellData.signal == pair.signal,
                    "Level \(level.id) pair at (\(pair.target.row),\(pair.target.col)) declares signal \(pair.signal) but target cell is \(String(describing: cellData.signal))"
                )
            }
        }
    }

    @Test func allLevelsHaveSolutionJSON() {
        let levels = CircuitLevelLoader.load()
        for level in levels {
            #expect(level.solutionStateJSON != nil, "Level \(level.id) missing solutionStateJSON")
        }
    }

    @Test func allSolutionJSONsDeserialize() throws {
        let levels = CircuitLevelLoader.load()
        for level in levels {
            let json = try #require(level.solutionStateJSON, "Level \(level.id) has nil solutionStateJSON")
            let state = try #require(CircuitStateSerializer.deserialize(json), "Level \(level.id) solutionStateJSON fails to deserialize")
            #expect(state.activePaths.isEmpty == false, "Level \(level.id) has empty solution paths")
        }
    }

    @Test func inBoundsTerminalPairTargetsMapToTargetCells() {
        let levels = CircuitLevelLoader.load()
        for level in levels {
            let liveGrid = level.makeLiveGrid()
            for pair in level.terminalPairs {
                guard pair.target.row >= 0,
                      pair.target.col >= 0,
                      pair.target.row < level.size,
                      pair.target.col < level.size else {
                    continue
                }

                let isTargetCell: Bool
                if case .terminal(_, _, false, _) = liveGrid[pair.target.row][pair.target.col] {
                    isTargetCell = true
                } else {
                    isTargetCell = false
                }

                #expect(
                    isTargetCell,
                    "Level \(level.id) has terminalPair target [\(pair.target.row), \(pair.target.col)] that is not a target terminal"
                )
            }
        }
    }

    @MainActor
    @Test func allCuratedSolutionsReplayToSolvedState() throws {
        let levels = CircuitLevelLoader.load()
        for level in levels {
            let json = try #require(level.solutionStateJSON, "Level \(level.id) has nil solutionStateJSON")
            let state = try #require(
                CircuitStateSerializer.deserialize(json),
                "Level \(level.id) solutionStateJSON fails to deserialize"
            )

            let vm = CircuitGameViewModel(levelId: level.id)
            vm.restoreState(from: state)

            #expect(vm.allTerminalsPowered, "Level \(level.id) replayed solution does not power all required targets")
            #expect(vm.allWaypointsVisited, "Level \(level.id) replayed solution does not visit all waypoints")
        }
    }

    @Test func gridDimensionsMatchSize() {
        let levels = CircuitLevelLoader.load()
        for level in levels {
            #expect(level.grid.count == level.size, "Level \(level.id) grid row count != size")
            for row in level.grid {
                #expect(row.count == level.size, "Level \(level.id) grid col count != size")
            }
        }
    }
}

// MARK: - Star Rating

@MainActor
struct CircuitStarRatingTests {

    @Test func levelOneCompletionGivesAtLeastOneStar() {
        let vm = CircuitGameViewModel(levelId: 1)

        // Level 1: Blue (0,0)→(0,3), Red (3,0)→(3,3) on a 4×4 grid
        vm.dragBegan(at: GridPosition(0, 0))
        vm.dragMoved(to: GridPosition(0, 1))
        vm.dragMoved(to: GridPosition(0, 2))
        vm.dragMoved(to: GridPosition(0, 3))
        vm.dragEnded()

        vm.dragBegan(at: GridPosition(3, 0))
        vm.dragMoved(to: GridPosition(3, 1))
        vm.dragMoved(to: GridPosition(3, 2))
        vm.dragMoved(to: GridPosition(3, 3))
        vm.dragEnded()

        let stars = vm.calculateStarRating()
        #expect(stars >= 1)
    }

    @Test func zeroStarsWhenNotComplete() {
        let vm = CircuitGameViewModel(levelId: 1)
        #expect(vm.calculateStarRating() == 0)
    }
}

// MARK: - Daily Generator

struct CircuitDailyGeneratorTests {

    @Test func dailyLevelIsDeterministic() {
        let date = Date(timeIntervalSince1970: 1_776_000_000)
        let level1 = CircuitLevelGenerator.generate(for: date)
        let level2 = CircuitLevelGenerator.generate(for: date)

        #expect(level1.seed == level2.seed)
        #expect(level1.size == level2.size)
        #expect(level1.terminalPairs.count == level2.terminalPairs.count)
    }

    @Test func dailyLevelHasTerminalPairs() {
        let level = CircuitLevelGenerator.generate(for: .now)
        #expect(level.terminalPairs.isEmpty == false)
    }

    /// Daily levels are produced by `CircuitLevelGenerator` which today
    /// deterministically selects from curated content. Regardless of the
    /// backing mechanism, a daily level must be sized as a playable board.
    @Test func dailyLevelHasPlayableSize() {
        let level = CircuitLevelGenerator.generate(for: .now)
        #expect(level.size >= 4, "Daily level is too small to be playable")
        #expect(level.size <= 10, "Daily level is unexpectedly large")
        #expect(level.grid.count == level.size)
    }

    @Test func dailyLevelHasSolutionJSON() {
        let level = CircuitLevelGenerator.generate(for: .now)
        #expect(level.solutionStateJSON != nil)
    }
}

// MARK: - Draw-Order Preservation (Save / Restore)

/// Protects the "your game" replay path: a partial, non-winning save must
/// restore byte-for-byte to what the player left on the board. This is the
/// class of bug where a dict-ordered save could flip which color fed a
/// Synthesizer and produce a visibly different board on restore.
@MainActor
struct CircuitDrawOrderFidelityTests {

    @Test func drawnColorOrderPersistsThroughSaveAndRestore() throws {
        // Level 6 is a classic synth board: blue+red → purple.
        let vm = CircuitGameViewModel(levelId: 6)

        // Draw blue first — trace a path that hits the synth.
        vm.dragBegan(at: GridPosition(0, 0))
        vm.dragMoved(to: GridPosition(0, 1))
        vm.dragMoved(to: GridPosition(0, 2))
        vm.dragMoved(to: GridPosition(1, 2))
        vm.dragMoved(to: GridPosition(2, 2)) // synth on L6
        vm.dragEnded()

        // Draw red second — a short path that stops before the synth.
        vm.dragBegan(at: GridPosition(4, 0))
        vm.dragMoved(to: GridPosition(3, 0))
        vm.dragMoved(to: GridPosition(2, 0))
        vm.dragEnded()

        #expect(vm.drawnColorOrder == [.blue, .red])

        // Serialize → decode → the pathOrder must match verbatim.
        let result = vm.buildGameResult()
        let json = try #require(result.circuitStateJSON)
        let state = try #require(CircuitStateSerializer.deserialize(json))
        #expect(state.pathOrder == [.blue, .red])

        // A fresh view model restoring the state must rebuild `drawnColorOrder`
        // in the same order — the property is the single source of truth for
        // subsequent save operations.
        let other = CircuitGameViewModel(levelId: 6)
        other.restoreState(from: state)
        #expect(other.drawnColorOrder == [.blue, .red])
    }

    /// Drawing red-first-then-blue on a synth level must replay with the
    /// same ordering in `drawnColorOrder`. This is the exact scenario the
    /// dict-ordered save was silently flipping.
    @Test func synthDrawOrderSurvivesRoundTrip() throws {
        let vm = CircuitGameViewModel(levelId: 6)

        // Red first this time.
        vm.dragBegan(at: GridPosition(4, 0))
        vm.dragMoved(to: GridPosition(3, 0))
        vm.dragMoved(to: GridPosition(2, 0))
        vm.dragMoved(to: GridPosition(2, 1))
        vm.dragMoved(to: GridPosition(2, 2)) // enter synth as first arrival
        vm.dragEnded()

        vm.dragBegan(at: GridPosition(0, 0))
        vm.dragMoved(to: GridPosition(0, 1))
        vm.dragEnded()

        #expect(vm.drawnColorOrder == [.red, .blue])

        let result = vm.buildGameResult()
        let json = try #require(result.circuitStateJSON)
        let state = try #require(CircuitStateSerializer.deserialize(json))
        #expect(state.pathOrder == [.red, .blue])

        let replay = CircuitGameViewModel(levelId: 6)
        replay.restoreState(from: state)
        #expect(replay.drawnColorOrder == [.red, .blue])

        // Partial synth must remember red as its first-and-only arrival so
        // the next input (blue, from anywhere) would mix correctly.
        if case .gate(_, let gateState) = replay.liveGrid[2][2],
           case .partiallyFilled(let inputs) = gateState {
            #expect(inputs.count == 1)
            #expect(inputs.first?.color == .red,
                    "Partial synth should log red as first arrival; saw \(inputs.map(\.color))")
        } else {
            Issue.record("Expected partiallyFilled synth at (2,2) after replay")
        }
    }

    /// A non-winning snapshot — the classic "gave up" or "mid-game leave" case
    /// — must replay exactly the segments that were persisted, without the
    /// permutation-fallback silently rearranging things into something the
    /// player never drew.
    @Test func nonWinningSnapshotReplaysFaithfully() throws {
        let vm = CircuitGameViewModel(levelId: 6)

        vm.dragBegan(at: GridPosition(0, 0))
        vm.dragMoved(to: GridPosition(0, 1))
        vm.dragMoved(to: GridPosition(1, 1))
        vm.dragEnded()

        #expect(vm.allTerminalsPowered == false,
                "Setup assumes an unfinished board")

        let result = vm.buildGameResult()
        let json = try #require(result.circuitStateJSON)
        let state = try #require(CircuitStateSerializer.deserialize(json))

        let replay = CircuitGameViewModel(levelId: 6)
        replay.restoreState(from: state)

        let original = try #require(vm.activePaths[.blue])
        let restored = try #require(replay.activePaths[.blue])
        #expect(original.segments == restored.segments)
        #expect(Set(vm.pathLayer.keys) == Set(replay.pathLayer.keys),
                "Restored pathLayer must cover the exact same cells as the original")
    }
}
