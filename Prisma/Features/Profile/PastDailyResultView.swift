//
//  PastDailyResultView.swift
//  Prisma
//
//  Shows a past daily game result with optional solution (for wrong answers or review).
//

import SwiftUI
import SwiftData

struct PastDailyResultView: View {
    let result: GameResult
    @State private var showSolution = false
    @State private var displayMode: HistoryDisplayMode = .userState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var gameColor: Color {
        switch result.gameType {
        case .signals: return AppTheme.signals
        case .archive: return AppTheme.archive
        case .cargo:   return AppTheme.cargo
        default: return .secondary
        }
    }
    
    private var hasUserState: Bool {
        switch result.gameType {
        case .cargo: return result.cargoStateJSON != nil
        case .signals: return result.signalsStateJSON != nil
        case .archive: return result.archiveStateJSON != nil
        case .shift: return result.shiftStateJSON != nil
        case .circuit: return result.circuitStateJSON != nil
        }
    }

    private var formattedDate: String {
        result.date.formatted(date: .abbreviated, time: .omitted)
    }
    
    private var toggleControl: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
                displayMode = displayMode == .userState ? .solution : .userState
            }
        } label: {
            HStack {
                Image(systemName: displayMode == .userState ? "person.fill" : "checkmark.seal.fill")
                Text(displayMode == .userState ? "Show Solution" : "Show Your Game")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(gameColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(gameColor.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Summary card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(result.gameType.displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(gameColor)
                        Spacer()
                        Text(formattedDate)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 20) {
                        statBadge("Score", value: "\(result.score)")
                        if result.gameType != .cargo {
                            statBadge("Guesses", value: "\(result.guessCount)")
                        }
                        if result.durationSeconds > 0 {
                            let m = Int(result.durationSeconds) / 60
                            let s = Int(result.durationSeconds) % 60
                            statBadge("Time", value: "\(m):\(s.formatted(.number.precision(.integerLength(2))))")
                        }
                    }
                    if !result.shareString.isEmpty {
                        Text(result.shareString)
                            .font(.caption.weight(.semibold).monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

                // Show solution toggle
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3)) { showSolution.toggle() }
                } label: {
                    HStack {
                        Image(systemName: showSolution ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                            .font(.title2)
                        Text(showSolution ? "Hide solution" : "Show solution")
                            .font(.body.weight(.semibold))
                        Spacer()
                    }
                    .foregroundStyle(gameColor)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(gameColor.opacity(0.12)))
                }
                .buttonStyle(.plain)

                if showSolution {
                    VStack(alignment: .leading, spacing: 16) {
                        // Toggle control (only if user state available)
                        if hasUserState {
                            toggleControl
                            
                            Divider()
                                .padding(.vertical, 4)
                        }
                        
                        // Display mode label
                        Text(displayMode == .userState && hasUserState ? "Your Game" : "Solution")
                            .font(.caption2.weight(.heavy).monospaced())
                            .foregroundStyle(.secondary)
                            .kerning(1)
                        
                        // Content based on display mode
                        contentView
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Past result")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statBadge(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if displayMode == .userState && hasUserState {
            userStateContent
        } else {
            solutionContent
        }
    }
    
    @ViewBuilder
    private var userStateContent: some View {
        switch result.gameType {
        case .signals:
            signalsUserState
        case .archive:
            archiveUserState
        case .cargo:
            cargoUserState
        case .shift:
            shiftUserState
        case .circuit:
            DailyCompletedCircuitUserState(result: result)
        }
    }

    @ViewBuilder
    private var solutionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch result.gameType {
            case .signals:
                signalsSolution
            case .archive:
                archiveSolution
            case .cargo:
                cargoSolution
            case .shift:
                shiftSolution
            case .circuit:
                DailyCompletedCircuitSolution(result: result)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var signalsSolution: some View {
        let code = SignalsCode(fromSeed: result.date.dailySeed)
        let digits = code.digits.map { "\($0)" }.joined(separator: " ")
        return VStack(alignment: .leading, spacing: 8) {
            Text("The code was:")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(digits)
                .font(.title.weight(.bold).monospaced())
                .foregroundStyle(.primary)
        }
    }

    private var archiveSolution: some View {
        let event = ArchiveGameViewModel.dailyEvent(for: result.date)
        return VStack(alignment: .leading, spacing: 8) {
            Text(event.hint)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(event.event)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text(event.dateString)
                .font(.body.weight(.medium).monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var cargoSolution: some View {
        // Show the player's own final grid — it IS the solution.
        // Re-generating via populateSolutionMode with puzzle.pieces causes pieces
        // to appear at (0,0) instead of their solved positions for JSON puzzles.
        cargoUserState
    }
    
    // MARK: - User State Rendering
    
    private var cargoUserState: some View {
        guard let json = result.cargoStateJSON,
              let grid = CargoStateSerializer.deserialize(json) else {
            return AnyView(
                VStack(spacing: 8) {
                    Text("Game history unavailable for games before this feature")
                        .font(.callout)
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
                .frame(height: 220)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        )
    }
    
    private var signalsUserState: some View {
        guard let json = result.signalsStateJSON,
              let guesses = SignalsStateSerializer.deserialize(json) else {
            return AnyView(
                VStack(spacing: 8) {
                    Text("Game history unavailable for games before this feature")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            )
        }
        
        let won = result.score > 0
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
                        .font(.title3.weight(.bold).monospaced())
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
                    .font(.title2)
                    .foregroundStyle(gameColor)
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
        guard let json = result.archiveStateJSON,
              let guesses = ArchiveStateSerializer.deserialize(json) else {
            return AnyView(
                VStack(spacing: 8) {
                    Text("Game history unavailable for games before this feature")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            )
        }
        
        let won = result.score > 0
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
                    .font(.title3.weight(.semibold).monospaced())
                Text("/")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                // Month
                Text("\(guessWithFeedback.guess.digits[2])\(guessWithFeedback.guess.digits[3])")
                    .font(.title3.weight(.semibold).monospaced())
                Text("/")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                // Year
                Text("\(guessWithFeedback.guess.digits[4])\(guessWithFeedback.guess.digits[5])\(guessWithFeedback.guess.digits[6])\(guessWithFeedback.guess.digits[7])")
                    .font(.title3.weight(.semibold).monospaced())
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
                    .font(.title2)
                    .foregroundStyle(gameColor)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func arrowIndicator(for result: DigitResult) -> some View {
        Group {
            switch result {
            case .correct:
                Image(systemName: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(AppTheme.signals)
            case .misplaced:
                Image(systemName: "arrow.up.circle.fill")
                    .font(.callout)
                    .foregroundStyle(AppTheme.misplacedBright)
            case .absent:
                Image(systemName: "arrow.down.circle.fill")
                    .font(.callout)
                    .foregroundStyle(AppTheme.error)
            }
        }
    }
    
    // MARK: - Shift Game Views
    
    private var shiftSolution: some View {
        let puzzle = ShiftPuzzleGenerator.generateDailyPuzzle(for: result.date)
        return VStack(spacing: 12) {
            if let solGrid = puzzle.solutionGrid {
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
                Text("Solution unavailable")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
    
    private var shiftUserState: some View {
        guard let json = result.shiftStateJSON,
              let state = ShiftStateSerializer.deserialize(json),
              let grid = state.toShiftGrid() else {
            return AnyView(
                VStack(spacing: 8) {
                    Text("Game history unavailable for games before this feature")
                        .font(.callout)
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
                
                // Grid view (read-only)
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
                .frame(height: 280)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.backgroundSecondary))
        )
    }
}

#Preview {
    NavigationStack {
        PastDailyResultView(result: GameResult(
            gameType: .signals,
            date: .now,
            score: 1000,
            shareString: "Prisma Signals 3/5",
            guessCount: 3,
            isDaily: true,
            durationSeconds: 120
        ))
    }
    .modelContainer(for: [GameResult.self], inMemory: true)
}
