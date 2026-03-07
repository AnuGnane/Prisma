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
    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        switch game {
        case .signals: return Color(red: 0.24, green: 0.65, blue: 0.36)
        case .archive: return Color(red: 0.24, green: 0.52, blue: 0.85)
        case .cargo:   return Color(red: 1.00, green: 0.55, blue: 0.26)
        default: return .secondary
        }
    }
    
    private var hasUserState: Bool {
        guard let result = gameResult else { return false }
        switch game {
        case .cargo: return result.cargoStateJSON != nil
        case .signals: return result.signalsStateJSON != nil
        case .archive: return result.archiveStateJSON != nil
        default: return false
        }
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
                        .foregroundStyle(won ? accentColor : Color(red: 0.85, green: 0.30, blue: 0.30))
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
            default:
                EmptyView()
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
        default:
            EmptyView()
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
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.07, green: 0.07, blue: 0.10)))
        )
    }
    
    // MARK: - User State Rendering
    
    private var cargoUserState: some View {
        guard let result = gameResult,
              let json = result.cargoStateJSON,
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
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.07, green: 0.07, blue: 0.10)))
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
                    .foregroundStyle(accentColor)
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
}

#Preview {
    NavigationStack {
        LocalLevelSolutionView(game: .signals, levelId: 1, won: true, score: 1000, gameResult: nil)
    }
}
