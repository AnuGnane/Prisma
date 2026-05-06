//
//  CargoGameViewModel.swift
//  Prisma
//
//  Drives all Cargo game logic:
//    - Tap-to-place piece placement with ghost preview
//    - Limited undo (last piece only, max 3)
//    - Timer (display only, does not affect score)
//    - Score: fill percentage × 10, bonus for perfect clear
//    - Daily and local level modes
//

import Foundation
import Observation

// MARK: - Game State

enum CargoGameState: Equatable {
    case notStarted
    case inProgress
    case completed(score: Int, isPerfect: Bool)
}

// MARK: - ViewModel

@Observable @MainActor
final class CargoGameViewModel {

    // MARK: - Game Data

    private(set) var puzzle: CargoPuzzle
    private(set) var pieces: [CargoPiece]       // all puzzle pieces (mutable for rotate/flip)
    private(set) var grid: CargoGrid
    private(set) var placedPieceIds: Set<Int> = []
    private(set) var gameState: CargoGameState = .inProgress

    // MARK: - Interaction State

    // Note: selectedPieceIndex is kept temporarily for undo auto-selection, but primarily we use:
    private(set) var selectedPieceIndex: Int? = nil
    
    // Drag & Drop / Pending State
    private(set) var draggingPieceId: Int? = nil
    private(set) var ghostOrigin: CellCoord? = nil
    
    private(set) var pendingPieceId: Int? = nil
    private(set) var pendingOrigin: CellCoord? = nil
    private var lastValidOrigin: CellCoord? = nil

    var isAwaitingSubmit: Bool { pendingPieceId != nil }
    private(set) var showingSolution: Bool = false

    // MARK: - Undo

    private(set) var undoCount: Int = 0
    static let maxUndos = 3
    var canUndo: Bool { undoCount < CargoGameViewModel.maxUndos && !placedPieceIds.isEmpty && !isAwaitingSubmit }

    // MARK: - Timer

    private(set) var elapsedSeconds: Int = 0
    private var timerTask: Task<Void, Never>?

    // MARK: - Mode

    let isDaily: Bool
    let activeLevelId: Int?

    // MARK: - Init (Daily)

    init(date: Date = .now) {
        self.isDaily = true
        self.activeLevelId = nil
        let p = CargoPuzzleLoader.dailyPuzzle(for: date) ?? Self.fallbackPuzzle()
        self.puzzle = p
        self.pieces = p.pieces
        self.grid = CargoGrid(rows: p.gridRows, cols: p.gridCols, blockedCells: p.blockedCells)
        startTimer()
    }

    // MARK: - Init (Local Level)

    init(level: Int) {
        self.isDaily = false
        self.activeLevelId = level
        let p = CargoPuzzleLoader.puzzle(for: level) ?? Self.fallbackPuzzle()
        self.puzzle = p
        self.pieces = p.pieces
        self.grid = CargoGrid(rows: p.gridRows, cols: p.gridCols, blockedCells: p.blockedCells)
        startTimer()
    }


    // MARK: - Helpers

    func piece(with id: Int) -> CargoPiece? {
        pieces.first(where: { $0.id == id })
    }

    // MARK: - Legacy Piece Selection (kept for tests/undo fallback)

    func selectPiece(at index: Int) {
        guard !isPiecePlaced(at: index) else { return }
        
        // While a piece is pending on the grid, ignore tray taps so the submit bar and shape persist.
        // Pending is only cleared by X or Submit. (Stray taps can occur during drag-release transition.)
        if isAwaitingSubmit {
            return
        }
        
        // If a previous drag was cancelled by the system (no drop callback), we can get stuck
        // with draggingPieceId set. Clear it so the user can tap a piece to recover.
        if draggingPieceId != nil {
            draggingPieceId = nil
            ghostOrigin = nil
            lastValidOrigin = nil
        }
        selectedPieceIndex = index
    }

    func isPiecePlaced(at index: Int) -> Bool {
        placedPieceIds.contains(pieces[index].id)
    }

    func isPiecePlaced(id: Int) -> Bool {
        placedPieceIds.contains(id)
    }

    // MARK: - Drag & Drop Interactions

    func beginDrag(pieceId: Int) {
        guard gameState == .inProgress else { return }
        
        // Prevent dragging already placed pieces
        guard !isPiecePlaced(id: pieceId) else { return }
        
        // Never clear pending when drag starts from the grid (same piece). Keeps submit/flip/rotate bar
        // and shape on screen until user explicitly taps X or Submit. User can move by cancelling (X) then re-dragging from tray.
        if pieceId == pendingPieceId {
            return
        }
        
        // Dragging a different piece from the tray while another is pending — cancel the pending piece
        if isAwaitingSubmit {
            cancelPendingPiece()
        }
        lastValidOrigin = nil
        
        selectedPieceIndex = nil // Clear multi-select overlay when dragging begins
        draggingPieceId = pieceId
        ghostOrigin = nil
        Haptics.playLightImpact()
        SoundManager.playTap()
    }

    func cancelDrag() {
        guard draggingPieceId != nil else { return }
        
        if let pId = draggingPieceId, let restoreOrigin = lastValidOrigin, piece(with: pId) != nil {
            // This piece was previously valid on the board, restore to pending state there
            pendingPieceId = pId
            pendingOrigin = restoreOrigin
            lastValidOrigin = nil
        }
        draggingPieceId = nil
        ghostOrigin = nil
    }

    func updateDragLocation(coord: CellCoord?) {
        guard let pId = draggingPieceId, let coord = coord, let piece = piece(with: pId) else {
            ghostOrigin = coord
            return
        }
        
        let bounds = piece.bounds
        let originR = coord.row - (bounds.rows / 2)
        let originC = coord.col - (bounds.cols / 2)
        
        ghostOrigin = CellCoord(originR, originC)
    }

    func dropDraggingPiece() {
        guard let pId = draggingPieceId, let origin = ghostOrigin, let piece = piece(with: pId) else {
            // Ghost origin is nil (piece was dragged off screen) or no drag in progress
            // — return piece to tray cleanly.
            draggingPieceId = nil
            ghostOrigin = nil
            lastValidOrigin = nil
            return
        }
        
        if grid.canPlace(piece, at: origin) {
            // Valid drop -> enter pending state
            pendingPieceId = pId
            pendingOrigin = origin
            lastValidOrigin = nil // Success, so clear restore point
            selectedPieceIndex = nil // Deselect tray item when placed
            Haptics.playMediumImpact()
            SoundManager.playClick()
        } else if let restoreOrigin = lastValidOrigin {
            // Invalid drop but it was a pending piece -> restore it!
            pendingPieceId = pId
            pendingOrigin = restoreOrigin
            lastValidOrigin = nil
            Haptics.playError()
        } else {
            // Invalid drop with nowhere to restore — cancel cleanly so piece returns to tray.
            cancelPendingPiece()
            Haptics.playError()
        }
        
        // Reset drag tracking
        draggingPieceId = nil
        ghostOrigin = nil
    }

    // MARK: - Pending State Actions

    func submitPendingPiece() {
        guard let pId = pendingPieceId, let origin = pendingOrigin, let piece = piece(with: pId) else { return }
        
        if grid.canPlace(piece, at: origin) {
            grid.place(piece, at: origin)
            placedPieceIds.insert(pId)
            
            Haptics.playMediumImpact()
            SoundManager.playClick()
            
            // Auto complete check
            checkCompletion()
        }
        
        pendingPieceId = nil
        pendingOrigin = nil
        selectedPieceIndex = nil
    }

    func cancelPendingPiece() {
        pendingPieceId = nil
        pendingOrigin = nil
    }

    func rotatePendingPiece() {
        guard let pId = pendingPieceId, let idx = pieces.firstIndex(where: { $0.id == pId }) else { return }
        pieces[idx] = pieces[idx].rotated()
        Haptics.playLightImpact()
        SoundManager.playTap()
    }

    func flipPendingPiece() {
        guard let pId = pendingPieceId, let idx = pieces.firstIndex(where: { $0.id == pId }) else { return }
        pieces[idx] = pieces[idx].flipped()
        Haptics.playLightImpact()
        SoundManager.playTap()
    }

    // MARK: - Rotate / Flip Selected (Legacy)

    func rotateSelectedPiece() {
        guard let idx = selectedPieceIndex else { return }
        pieces[idx] = pieces[idx].rotated()
        ghostOrigin = nil
    }

    func flipSelectedPiece() {
        guard let idx = selectedPieceIndex else { return }
        pieces[idx] = pieces[idx].flipped()
        ghostOrigin = nil
    }

    // MARK: - Tap Grid Cell (Legacy, no-op)

    func tapCell(_ coord: CellCoord) {
        // Disabled for drag and drop
    }

    // MARK: - Ghost Preview

    func hoverCell(_ coord: CellCoord?) {
        ghostOrigin = coord
    }

    /// Cells to highlight for the pending or dragging piece
    var ghostCells: [CellCoord] {
        if let pId = pendingPieceId, let origin = pendingOrigin, let piece = piece(with: pId) {
            return grid.absoluteCells(for: piece, at: origin)
        }
        guard let pId = draggingPieceId ?? (selectedPieceIndex != nil ? pieces[selectedPieceIndex!].id : nil),
              let origin = ghostOrigin, let piece = piece(with: pId) else { return [] }
        return grid.absoluteCells(for: piece, at: origin)
    }

    var ghostIsValid: Bool {
        if let pId = pendingPieceId, let origin = pendingOrigin, let piece = piece(with: pId) {
            return grid.canPlace(piece, at: origin)
        }
        guard let pId = draggingPieceId ?? (selectedPieceIndex != nil ? pieces[selectedPieceIndex!].id : nil),
              let origin = ghostOrigin, let piece = piece(with: pId) else { return false }
        return grid.canPlace(piece, at: origin)
    }

    // MARK: - Undo

    func undoLastPlacement() {
        guard canUndo else { return }
        if let removed = grid.undoLastPlacement() {
            placedPieceIds.remove(removed.pieceId)
            // Restore piece's transformations
            if let pidx = pieces.firstIndex(where: { $0.id == removed.pieceId }) {
                pieces[pidx].rotationSteps = removed.rotationSteps
                pieces[pidx].isFlipped = removed.isFlipped
                selectedPieceIndex = pidx
            }
            undoCount += 1
        }
    }

    // MARK: - Give Up / Done

    func submitResult() {
        guard gameState == .inProgress else { return }
        timerTask?.cancel()
        let score = calculateScore()
        let isPerfect = grid.isPerfectlyClear
        gameState = .completed(score: score, isPerfect: isPerfect)
    }

    // MARK: - Private Helpers

    private func checkCompletion() {
        // All pieces placed = game over
        let allPlaced = pieces.allSatisfy { placedPieceIds.contains($0.id) }
        if allPlaced {
            timerTask?.cancel()
            let score = calculateScore()
            let isPerfect = grid.isPerfectlyClear
            gameState = .completed(score: score, isPerfect: isPerfect)
        }
    }

    private func calculateScore() -> Int {
        let fill = grid.fillPercentage               // 0.0..1.0
        let base = Int(fill * 1000)                  // 0–1000
        return min(1000, base)
    }

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self = self else { break }
                await MainActor.run { self.elapsedSeconds += 1 }
            }
        }
    }

    // MARK: - Timer Display

    var timerString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return "\(m):\(s.formatted(.number.precision(.integerLength(2))))"
    }

    // MARK: - Computed Stats

    var fillPercentage: Double { grid.fillPercentage }
    var piecesRemaining: Int { pieces.count - placedPieceIds.count }
    var isGameOver: Bool {
        if case .completed = gameState { return true }
        return false
    }

    // MARK: - Show Solution

    func showSolution() {
        guard isGameOver else { return }
        showingSolution = true
    }

    /// Constructs a fresh grid filled according to each piece's canonical
    /// `solutionCells`. Returns `nil` if any piece lacks solution data, in
    /// which case `CargoSolutionGrid` falls back to the player's own grid
    /// rather than producing a garbage 0,0-stacked layout.
    func buildSolutionGrid() -> CargoGrid? {
        guard pieces.allSatisfy({ ($0.solutionCells?.isEmpty == false) }) else {
            return nil
        }
        var solved = CargoGrid(
            rows: puzzle.gridRows,
            cols: puzzle.gridCols,
            blockedCells: puzzle.blockedCells
        )
        solved.populateSolutionMode(with: pieces)
        return solved
    }

    // MARK: - Share & Persistence (Daily)

    /// Share string for daily Cargo: pieces placed out of total, and empty squares if any.
    func generateShareString() -> String {
        let placed = placedPieceIds.count
        let total = pieces.count
        let empty = grid.emptyCellCount
        if empty == 0 {
            return "Prisma Cargo · \(placed)/\(total) pieces ✓"
        }
        return "Prisma Cargo · \(placed)/\(total) pieces · \(empty) empty"
    }

    /// Build a GameResult for saving daily Cargo completion. Use the given date as the game date (start of day).
    func buildGameResult(gameDate: Date) -> GameResult {
        let score: Int
        if case .completed(let s, _) = gameState { score = s } else { score = 0 }
        
        // Serialize the final grid state
        let serializedState = CargoStateSerializer.serialize(grid)
        if serializedState == nil {
            print("⚠️ CargoGameViewModel: Failed to serialize grid state for daily game")
        }
        
        return GameResult(
            gameType: .cargo,
            date: gameDate,
            score: score,
            shareString: generateShareString(),
            guessCount: 0,
            isDaily: true,
            durationSeconds: Double(elapsedSeconds),
            cargoStateJSON: serializedState
        )
    }
    
    /// Build a GameResult for saving local level Cargo completion.
    func buildLocalGameResult() -> GameResult {
        let score: Int
        if case .completed(let s, _) = gameState { score = s } else { score = 0 }
        
        // Serialize the final grid state
        let serializedState = CargoStateSerializer.serialize(grid)
        if serializedState == nil {
            print("⚠️ CargoGameViewModel: Failed to serialize grid state for local game")
        }
        
        return GameResult(
            gameType: .cargo,
            date: .now,
            score: score,
            shareString: generateShareString(),
            guessCount: 0,
            isDaily: false,
            durationSeconds: Double(elapsedSeconds),
            levelId: activeLevelId,
            cargoStateJSON: serializedState
        )
    }

    // MARK: - Fallback Puzzle

    private static func fallbackPuzzle() -> CargoPuzzle {
        let pieces = [
            CargoPiece(id: 1, baseCells: [CellCoord(0,0),CellCoord(0,1),CellCoord(1,0),CellCoord(1,1)]),
            CargoPiece(id: 2, baseCells: [CellCoord(0,0),CellCoord(0,1),CellCoord(1,0),CellCoord(1,1)]),
            CargoPiece(id: 3, baseCells: [CellCoord(0,0),CellCoord(0,1),CellCoord(1,0),CellCoord(1,1)]),
            CargoPiece(id: 4, baseCells: [CellCoord(0,0),CellCoord(0,1),CellCoord(1,0),CellCoord(1,1)]),
        ]
        return CargoPuzzle(id: 0, gridRows: 4, gridCols: 4, blockedCells: [], pieces: pieces)
    }

    // MARK: - Load Level (for inline progression)

    func loadLevel(_ level: Int) {
        let p = CargoPuzzleLoader.puzzle(for: level) ?? Self.fallbackPuzzle()
        puzzle = p
        pieces = p.pieces
        grid = CargoGrid(rows: p.gridRows, cols: p.gridCols, blockedCells: p.blockedCells)
        placedPieceIds = []
        selectedPieceIndex = nil
        draggingPieceId = nil
        pendingPieceId = nil
        pendingOrigin = nil
        ghostOrigin = nil
        showingSolution = false
        undoCount = 0
        elapsedSeconds = 0
        gameState = .inProgress
        startTimer()
    }

    func reset() {
        if isDaily {
            let p = CargoPuzzleLoader.dailyPuzzle() ?? Self.fallbackPuzzle()
            puzzle = p
        } else if let levelId = activeLevelId {
            let p = CargoPuzzleLoader.puzzle(for: levelId) ?? Self.fallbackPuzzle()
            puzzle = p
        }
        
        pieces = puzzle.pieces
        grid = CargoGrid(rows: puzzle.gridRows, cols: puzzle.gridCols, blockedCells: puzzle.blockedCells)
        placedPieceIds = []
        selectedPieceIndex = nil
        draggingPieceId = nil
        pendingPieceId = nil
        pendingOrigin = nil
        ghostOrigin = nil
        showingSolution = false
        undoCount = 0
        elapsedSeconds = 0
        gameState = .inProgress
        timerTask?.cancel()
        startTimer()
    }
}

// MARK: - CargoPiece Init from bare components (for fallback)

extension CargoPiece {
    init(id: Int, baseCells: [CellCoord]) {
        self.id = id
        self.baseCells = baseCells
        self.rotationSteps = 0
        self.isFlipped = false
    }
}
