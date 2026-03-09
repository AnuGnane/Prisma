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

    private var gameColor: Color {
        switch result.gameType {
        case .signals: return Color(red: 0.24, green: 0.65, blue: 0.36)
        case .archive: return Color(red: 0.24, green: 0.52, blue: 0.85)
        case .cargo:   return Color(red: 1.00, green: 0.55, blue: 0.26)
        default: return .secondary
        }
    }
    
    private var hasUserState: Bool {
        switch result.gameType {
        case .cargo: return result.cargoStateJSON != nil
        case .signals: return result.signalsStateJSON != nil
        case .archive: return result.archiveStateJSON != nil
        case .shift: return result.shiftStateJSON != nil
        default: return false
        }
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: result.date)
    }
    
    private var toggleControl: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                displayMode = displayMode == .userState ? .solution : .userState
            }
        } label: {
            HStack {
                Image(systemName: displayMode == .userState ? "person.fill" : "checkmark.seal.fill")
                Text(displayMode == .userState ? "Show Solution" : "Show Your Game")
                    .font(.system(size: 15, weight: .semibold))
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
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(gameColor)
                        Spacer()
                        Text(formattedDate)
                            .font(.system(size: 15))
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
                            statBadge("Time", value: String(format: "%d:%02d", m, s))
                        }
                    }
                    if !result.shareString.isEmpty {
                        Text(result.shareString)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

                // Show solution toggle
                Button {
                    withAnimation(.spring(response: 0.3)) { showSolution.toggle() }
                } label: {
                    HStack {
                        Image(systemName: showSolution ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                            .font(.system(size: 20))
                        Text(showSolution ? "Hide solution" : "Show solution")
                            .font(.system(size: 17, weight: .semibold))
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
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
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
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 11))
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
        default:
            EmptyView()
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
            default:
                EmptyView()
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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text(digits)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    private var archiveSolution: some View {
        let event = ArchiveGameViewModel.dailyEvent(for: result.date)
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
    }

    private var cargoSolution: some View {
        guard let puzzle = CargoPuzzleLoader.dailyPuzzle(for: result.date) else {
            return AnyView(Text("Puzzle unavailable").foregroundStyle(.secondary))
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
            .frame(height: 220)
        )
    }
    
    // MARK: - User State Rendering
    
    private var cargoUserState: some View {
        guard let json = result.cargoStateJSON,
              let grid = CargoStateSerializer.deserialize(json) else {
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
                        .font(.system(size: 14))
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
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
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
                    .foregroundStyle(gameColor)
            }
        }
    }
    
    private func colorForDigitResult(_ result: DigitResult) -> Color {
        switch result {
        case .correct:
            return Color(red: 0.24, green: 0.65, blue: 0.36) // Green
        case .misplaced:
            return Color(red: 0.95, green: 0.77, blue: 0.06) // Yellow
        case .absent:
            return Color(red: 0.3, green: 0.3, blue: 0.3) // Grey
        }
    }
    
    private var archiveUserState: some View {
        guard let json = result.archiveStateJSON,
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
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 0.24, green: 0.65, blue: 0.36))
            case .misplaced:
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 0.95, green: 0.77, blue: 0.06))
            case .absent:
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 0.85, green: 0.30, blue: 0.30))
            }
        }
    }
    
    // MARK: - Shift Game Views
    
    private var shiftSolution: some View {
        Text("Shift solution view not yet implemented")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
    }
    
    private var shiftUserState: some View {
        guard let json = result.shiftStateJSON,
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
            if grid.containsWord(targetWord.word, at: targetWord.position) {
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
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.07, green: 0.07, blue: 0.10)))
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
