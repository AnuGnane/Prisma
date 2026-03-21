//
//  DailyCompletedView.swift
//  Prisma
//
//  Shown when the user navigates to a daily game they've already played today.
//

import SwiftUI

struct DailyCompletedView: View {
    let result: GameResult
    @State private var displayMode: HistoryDisplayMode = .userState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var gameColor: Color {
        AppTheme.accent(for: result.gameType)
    }

    private var won: Bool { result.score > 0 }
    
    private var hasUserState: Bool {
        switch result.gameType {
        case .cargo: return result.cargoStateJSON != nil
        case .signals: return result.signalsStateJSON != nil
        case .archive: return result.archiveStateJSON != nil
        case .shift: return result.shiftStateJSON != nil
        default: return false
        }
    }

    var body: some View {
        ZStack {
            AppTheme.appBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Icon + title
                    VStack(spacing: 14) {
                        Image(systemName: won ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(won ? gameColor : AppTheme.error)

                        Text(result.gameType.displayName.uppercased())
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.4))
                            .kerning(2)

                        Text(won ? "Completed Today" : "Played Today")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, 24)

                    // Stats
                    HStack(spacing: 24) {
                        if result.score > 0 {
                            DailyCompletedStatItem(label: "SCORE", value: "\(result.score)")
                        }
                        if result.guessCount > 0 {
                            DailyCompletedStatItem(label: result.gameType == .shift ? "MOVES" : "GUESSES",
                                     value: "\(result.guessCount)")
                        }
                        if result.durationSeconds > 0 {
                            DailyCompletedStatItem(label: "TIME", value: formatDuration(result.durationSeconds))
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.primary.opacity(0.07))
                    )

                    // Share
                    if !result.shareString.isEmpty {
                        ShareLink(item: result.shareString) {
                            Label("Share Result", systemImage: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(gameColor))
                        }
                        .padding(.horizontal, 12)
                    }

                    // Game board toggle + content
                    if hasUserState {
                        Divider()
                            .padding(.horizontal, 12)

                        DailyCompletedToggleControl(displayMode: $displayMode, gameColor: gameColor)
                        
                        Text(displayMode == .userState ? "Your Game" : "Solution")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .kerning(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        if displayMode == .userState {
                            userStateContent
                        } else {
                            solutionContent
                        }
                    }

                }
                .padding(.horizontal, 20)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - User State Views
    
    @ViewBuilder
    private var userStateContent: some View {
        switch result.gameType {
        case .signals: DailyCompletedSignalsUserState(result: result, won: won, gameColor: gameColor)
        case .archive: DailyCompletedArchiveUserState(result: result, won: won, gameColor: gameColor)
        case .cargo: DailyCompletedCargoUserState(result: result)
        case .shift: DailyCompletedShiftUserState(result: result)
        default: EmptyView()
        }
    }
    
    @ViewBuilder
    private var solutionContent: some View {
        switch result.gameType {
        case .signals: DailyCompletedSignalsSolution(result: result)
        case .archive: DailyCompletedArchiveSolution(result: result)
        case .cargo: DailyCompletedCargoSolution(result: result)
        case .shift: DailyCompletedShiftSolution(result: result)
        default: EmptyView()
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return "\(m):\(s.formatted(.number.precision(.integerLength(2))))"
    }
}

// MARK: - Subviews

struct DailyCompletedToggleControl: View {
    @Binding var displayMode: HistoryDisplayMode
    let gameColor: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
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
}

struct DailyCompletedSignalsUserState: View {
    let result: GameResult
    let won: Bool
    let gameColor: Color
    
    var body: some View {
        guard let json = result.signalsStateJSON,
              let guesses = SignalsStateSerializer.deserialize(json) else {
            return AnyView(DailyCompletedUnavailableView())
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(guesses.enumerated()), id: \.offset) { index, guess in
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            ForEach(0..<4, id: \.self) { i in
                                Text("\(guess.guess.digits[i])")
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(colorForDigitResult(guess.feedback.digitResults[i]))
                                    )
                            }
                        }
                        Spacer()
                        if won && index == guesses.count - 1 {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(gameColor)
                        }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.07)))
        )
    }
    
    private func colorForDigitResult(_ result: DigitResult) -> Color {
        switch result {
        case .correct: return AppTheme.signals
        case .misplaced: return AppTheme.misplacedBright
        case .absent: return Color.primary.opacity(0.30)
        }
    }
}

struct DailyCompletedSignalsSolution: View {
    let result: GameResult
    
    var body: some View {
        let code = SignalsCode(fromSeed: result.date.dailySeed)
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
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.07)))
    }
}

struct DailyCompletedArchiveUserState: View {
    let result: GameResult
    let won: Bool
    let gameColor: Color
    
    var body: some View {
        guard let json = result.archiveStateJSON,
              let guesses = ArchiveStateSerializer.deserialize(json) else {
            return AnyView(DailyCompletedUnavailableView())
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(guesses.enumerated()), id: \.offset) { index, guess in
                    HStack(spacing: 12) {
                        HStack(spacing: 2) {
                            Text("\(guess.guess.digits[0])\(guess.guess.digits[1])")
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            Text("/").font(.system(size: 18, weight: .semibold)).foregroundStyle(.secondary)
                            Text("\(guess.guess.digits[2])\(guess.guess.digits[3])")
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            Text("/").font(.system(size: 18, weight: .semibold)).foregroundStyle(.secondary)
                            Text("\(guess.guess.digits[4])\(guess.guess.digits[5])\(guess.guess.digits[6])\(guess.guess.digits[7])")
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            DailyCompletedArrowIndicator(result: guess.feedback.digitResults[0])
                            DailyCompletedArrowIndicator(result: guess.feedback.digitResults[2])
                            DailyCompletedArrowIndicator(result: guess.feedback.digitResults[4])
                        }
                        if won && index == guesses.count - 1 {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(gameColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.07)))
        )
    }
}

struct DailyCompletedArchiveSolution: View {
    let result: GameResult
    
    var body: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.07)))
    }
}

struct DailyCompletedCargoUserState: View {
    let result: GameResult
    
    var body: some View {
        guard let json = result.cargoStateJSON,
              let puzzle = CargoPuzzleLoader.dailyPuzzle(for: result.date),
              let grid = CargoStateSerializer.deserialize(json, originalPieces: puzzle.pieces) else {
            return AnyView(DailyCompletedUnavailableView())
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
}

struct DailyCompletedCargoSolution: View {
    let result: GameResult
    
    var body: some View {
        guard let puzzle = CargoPuzzleLoader.dailyPuzzle(for: result.date) else {
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
}

struct DailyCompletedShiftUserState: View {
    let result: GameResult
    
    var body: some View {
        guard let json = result.shiftStateJSON,
              let state = ShiftStateSerializer.deserialize(json),
              let grid = state.toShiftGrid() else {
            return AnyView(DailyCompletedUnavailableView())
        }
        
        let targetWords = state.targetWords.map { sw in
            TargetWord(
                word: sw.word,
                position: WordPosition(
                    row: sw.row,
                    startCol: sw.startCol,
                    direction: WordDirection(rawValue: sw.direction) ?? .horizontal
                )
            )
        }
        
        var completedWords: Set<UUID> = []
        for tw in targetWords {
            if grid.findWord(tw.word) != nil {
                completedWords.insert(tw.id)
            }
        }
        
        let allHighlighted: Set<Int> = {
            var cells = Set<Int>()
            for tw in targetWords where completedWords.contains(tw.id) {
                if let loc = grid.findWord(tw.word) {
                    for c in loc.cells { cells.insert(c.row * ShiftGrid.size + c.col) }
                }
            }
            return cells
        }()
        
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                TargetWordListView(
                    targetWords: targetWords,
                    completedWords: completedWords,
                    hintWord: nil
                )
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

struct DailyCompletedShiftSolution: View {
    let result: GameResult
    
    var body: some View {
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
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.07)))
    }
}

struct DailyCompletedUnavailableView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Game history unavailable")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.07)))
    }
}

struct DailyCompletedStatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.4))
                .kerning(1)
        }
    }
}

struct DailyCompletedArrowIndicator: View {
    let result: DigitResult
    
    var body: some View {
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
}
