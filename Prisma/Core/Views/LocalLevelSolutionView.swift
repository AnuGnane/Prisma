//
//  LocalLevelSolutionView.swift
//  Prisma
//
//  Read-only view of a local level's solution (for past games).
//

import SwiftUI
import SwiftData

enum HistoryDisplayMode {
    case userState
    case solution
}

struct LocalLevelSolutionView: View {
    let game: GameType
    let levelId: Int
    let won: Bool
    let score: Int
    let gameResult: GameResult?
    
    @State private var displayMode: HistoryDisplayMode = .userState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        switch game {
        case .signals: return AppTheme.signals
        case .archive: return AppTheme.archive
        case .cargo:   return AppTheme.cargo
        default: return .secondary
        }
    }
    
    private var hasUserState: Bool {
        guard let result = gameResult else { return false }
        switch game {
        case .cargo: return result.cargoStateJSON != nil
        case .signals: return result.signalsStateJSON != nil
        case .archive: return result.archiveStateJSON != nil
        case .shift: return result.shiftStateJSON != nil
        }
    }
    
    private var toggleControl: some View {
        Button {
            let updateMode = {
                displayMode = displayMode == .userState ? .solution : .userState
            }

            if reduceMotion {
                updateMode()
            } else {
                withAnimation(.spring(response: 0.3), updateMode)
            }
        } label: {
            HStack {
                Image(systemName: displayMode == .userState ? "person.fill" : "checkmark.seal.fill")
                Text(displayMode == .userState ? "Show Solution" : "Show Your Game")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Your result
                HStack(spacing: 12) {
                    Image(systemName: won ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(won ? accentColor : AppTheme.error)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(won ? "Level \(levelId) completed" : "Level \(levelId) — lost")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                        if game != .cargo {
                            Text("Score: \(score)")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Score: \(score)")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

                // Toggle control (only if user state available)
                if hasUserState {
                    toggleControl
                    
                    Divider()
                        .padding(.vertical, 4)
                }

                Text(displayMode == .userState && hasUserState ? "Your Game" : "Solution")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .kerning(1)

                solutionContent
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Level \(levelId)")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var solutionContent: some View {
        if displayMode == .userState && hasUserState {
            userStateContent
        } else {
            switch game {
            case .signals:
                signalsSolution
            case .archive:
                archiveSolution
            case .cargo:
                cargoSolution
            case .shift:
                shiftSolution
            }
        }
    }
    
    @ViewBuilder
    private var userStateContent: some View {
        switch game {
        case .signals:
            signalsUserState
        case .archive:
            archiveUserState
        case .cargo:
            cargoUserState
        case .shift:
            shiftUserState
        }
    }

    private var signalsSolution: some View {
        let code = SignalsCode(fromSeed: levelId * 1000)
        let digits = code.digits.map { "\($0)" }.joined(separator: " ")
        return VStack(alignment: .leading, spacing: 8) {
            Text("The code was:")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text(digits)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var archiveSolution: some View {
        let event = ArchiveGameViewModel.event(forLevel: levelId)
        return VStack(alignment: .leading, spacing: 8) {
            Text(event.hint)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text(event.event)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
            Text(event.dateString)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var cargoSolution: some View {
        guard let puzzle = CargoPuzzleLoader.puzzle(for: levelId) else {
            return AnyView(Text("Puzzle unavailable").foregroundStyle(.secondary).padding())
        }
        var grid = CargoGrid(rows: puzzle.gridRows, cols: puzzle.gridCols, blockedCells: puzzle.blockedCells)
        grid.populateSolutionMode(with: puzzle.pieces)
        return AnyView(
            CargoGridView(
                grid: grid,
                ghostCells: [],
                ghostIsValid: false,
                pendingCells: [],
                pendingPieceId: nil,
                onDragPending: nil,
                onHoverGrid: { _ in },
                onDropGrid: {}
            )
            .frame(height: 260)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.backgroundSecondary))
        )
    }
    
    // MARK: - User State Rendering
    
    private var historyUnavailableView: AnyView {
        AnyView(
            VStack(spacing: 8) {
                Text("Game history unavailable for games before this feature")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        )
    }

    private var cargoUserState: some View {
        guard let result = gameResult,
              let json = result.cargoStateJSON else {
            return historyUnavailableView
        }
        
        let originalPieces = CargoPuzzleLoader.puzzle(for: levelId)?.pieces
        guard let grid = CargoStateSerializer.deserialize(json, originalPieces: originalPieces) else {
            return historyUnavailableView
        }
        
        return AnyView(
            CargoGridView(
                grid: grid,
                ghostCells: [],
                ghostIsValid: false,
                pendingCells: [],
                pendingPieceId: nil,
                onDragPending: nil,
                onHoverGrid: { _ in },
                onDropGrid: {}
            )
            .frame(height: 260)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.backgroundSecondary))
        )
    }
    
    private var signalsUserState: some View {
        guard let result = gameResult,
              let json = result.signalsStateJSON,
              let guesses = SignalsStateSerializer.deserialize(json) else {
            return AnyView(
                VStack(spacing: 8) {
                    Text("Game history unavailable for games before this feature")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            )
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(guesses.enumerated()), id: \.offset) { index, guessWithFeedback in
                    signalsGuessRow(guessWithFeedback: guessWithFeedback, isWinning: won && index == guesses.count - 1)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        )
    }
    
    private func signalsGuessRow(guessWithFeedback: SignalsGuessWithFeedback, isWinning: Bool) -> some View {
        HStack(spacing: 8) {
            // Display the 4-digit code
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    let digit = guessWithFeedback.guess.digits[index]
                    let result = guessWithFeedback.feedback.digitResults[index]
                    
                    Text("\(digit)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorForDigitResult(result))
                        )
                }
            }
            
            Spacer()
            
            // Show winning indicator if this is the winning guess
            if isWinning {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(accentColor)
            }
        }
    }
    
    private func colorForDigitResult(_ result: DigitResult) -> Color {
        switch result {
        case .correct:
            return AppTheme.signals // Green
        case .misplaced:
            return AppTheme.misplacedBright // Yellow
        case .absent:
            return Color.primary.opacity(0.30) // Grey
        }
    }
    
    private var archiveUserState: some View {
        guard let result = gameResult,
              let json = result.archiveStateJSON,
              let guesses = ArchiveStateSerializer.deserialize(json) else {
            return AnyView(
                VStack(spacing: 8) {
                    Text("Game history unavailable for games before this feature")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            )
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(guesses.enumerated()), id: \.offset) { index, guessWithFeedback in
                    archiveGuessRow(guessWithFeedback: guessWithFeedback, isWinning: won && index == guesses.count - 1)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        )
    }
    
    private func archiveGuessRow(guessWithFeedback: ArchiveGuessWithFeedback, isWinning: Bool) -> some View {
        HStack(spacing: 12) {
            // Display the date in DD/MM/YYYY format
            HStack(spacing: 2) {
                // Day
                Text("\(guessWithFeedback.guess.digits[0])\(guessWithFeedback.guess.digits[1])")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                Text("/")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                // Month
                Text("\(guessWithFeedback.guess.digits[2])\(guessWithFeedback.guess.digits[3])")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                Text("/")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                // Year
                Text("\(guessWithFeedback.guess.digits[4])\(guessWithFeedback.guess.digits[5])\(guessWithFeedback.guess.digits[6])\(guessWithFeedback.guess.digits[7])")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
            }
            
            Spacer()
            
            // Arrow indicators for day, month, year
            HStack(spacing: 8) {
                arrowIndicator(for: guessWithFeedback.feedback.digitResults[0])
                arrowIndicator(for: guessWithFeedback.feedback.digitResults[2])
                arrowIndicator(for: guessWithFeedback.feedback.digitResults[4])
            }
            
            // Show winning indicator if this is the winning guess
            if isWinning {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(accentColor)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func arrowIndicator(for result: DigitResult) -> some View {
        Group {
            switch result {
            case .correct:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.signals)
            case .misplaced:
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.misplacedBright)
            case .absent:
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.error)
            }
        }
    }
    
    // MARK: - Shift Game Views
    
    private var shiftSolution: some View {
        // Load the solution grid from the level data
        VStack(spacing: 12) {
            if let puzzle = ShiftPuzzleLoader.loadLevel(levelId),
               let solGrid = puzzle.solutionGrid {
                let solHighlighted: Set<Int> = {
                    var cells = Set<Int>()
                    for tw in puzzle.targetWords {
                        if let loc = solGrid.findWord(tw.word) {
                            for c in loc.cells { cells.insert(c.row * ShiftGrid.size + c.col) }
                        }
                    }
                    return cells
                }()

                TargetWordListView(
                    targetWords: puzzle.targetWords,
                    completedWords: Set(puzzle.targetWords.map(\.id)),
                    hintWord: nil
                )

                ShiftGridView(
                    grid: .constant(solGrid),
                    highlightedCells: solHighlighted,
                    hintCells: [],
                    interactive: false,
                    onMove: { _ in }
                )
                .frame(maxHeight: 350)
            } else {
                Text("Solution unavailable for this level")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
    
    private var shiftUserState: some View {
        guard let result = gameResult,
              let json = result.shiftStateJSON,
              let state = ShiftStateSerializer.deserialize(json),
              let grid = state.toShiftGrid() else {
            return AnyView(
                VStack(spacing: 8) {
                    Text("Game history unavailable for games before this feature")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            )
        }
        
        // Convert serializable target words to TargetWord objects
        let targetWords = state.targetWords.map { serializableWord in
            TargetWord(
                word: serializableWord.word,
                position: WordPosition(
                    row: serializableWord.row,
                    startCol: serializableWord.startCol,
                    direction: WordDirection(rawValue: serializableWord.direction) ?? .horizontal
                )
            )
        }
        
        // Determine which words are completed in the final state
        var completedWords: Set<UUID> = []
        for targetWord in targetWords {
            if grid.findWord(targetWord.word) != nil {
                completedWords.insert(targetWord.id)
            }
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                // Target words list
                TargetWordListView(
                    targetWords: targetWords,
                    completedWords: completedWords,
                    hintWord: nil
                )
                
                // Grid view (read-only — highlight all completed word cells)
                let allHighlighted: Set<Int> = {
                    var cells = Set<Int>()
                    for tw in targetWords where completedWords.contains(tw.id) {
                        if let loc = grid.findWord(tw.word) {
                            for c in loc.cells { cells.insert(c.row * ShiftGrid.size + c.col) }
                        }
                    }
                    return cells
                }()

                ShiftGridView(
                    grid: .constant(grid),
                    highlightedCells: allHighlighted,
                    hintCells: [],
                    interactive: false,
                    onMove: { _ in }
                )
                .frame(height: 320)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.backgroundSecondary))
        )
    }
}

#Preview {
    NavigationStack {
        LocalLevelSolutionView(game: .signals, levelId: 1, won: true, score: 1000, gameResult: nil)
    }
}
