//
//  ArchiveGameView.swift
//  Prisma
//
//  Main container for Archive daily game.
//  Board: fixed maxGuesses rows — feedback / active input / empty
//  Active row: 8 cells in DD / MM / YYYY grouping with "/" separators
//  Header: "ARCHIVE" + counter pill + hint text
//

import SwiftUI
import SwiftData

@MainActor
struct ArchiveGameView: View {
    @State private var viewModel: ArchiveGameViewModel
    @State private var showResultSheet = false
    @State private var showGiveUpAlert = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: ArchiveGameViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    init() {
        _viewModel = State(initialValue: ArchiveGameViewModel(date: .now))
    }

    var body: some View {
        ZStack {
            // Background
            AppTheme.appBackground()

            VStack(spacing: 0) {
                ArchiveHeader(viewModel: viewModel, dismiss: dismiss, showGiveUpAlert: $showGiveUpAlert)
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                ArchiveBoard(viewModel: viewModel)
                    .padding(.horizontal, 16)

                Spacer(minLength: 8)

                if !viewModel.gameState.isOver {
                    ArchiveInputView(viewModel: viewModel) {
                        viewModel.submitGuess()
                        if viewModel.gameState.isOver {
                            // Save local level progress (win or loss)
                            if let levelId = viewModel.activeLevelId {
                                let didWin = viewModel.gameState.isCompleted
                                let score: Int
                                if case .completed(let s) = viewModel.gameState { score = s } else { score = 0 }
                                PersistenceManager.markLevelPlayed(
                                    gameType: .archive,
                                    levelId: levelId,
                                    won: didWin,
                                    score: score,
                                    guessesUsed: viewModel.guessCount,
                                    durationSeconds: Date.now.timeIntervalSince(viewModel.startDate),
                                    context: modelContext
                                )
                            }
                            // Save GameResult (prevent duplicate daily saves)
                            if !viewModel.isDaily || PersistenceManager.fetchDailyResult(for: .archive, on: .now, context: modelContext) == nil {
                                let result = viewModel.buildGameResult()
                                PersistenceManager.save(result, context: modelContext)
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                if viewModel.gameState.isCompleted { Haptics.playSuccess() }
                                else { Haptics.playMediumImpact() }
                                
                                if viewModel.isDaily {
                                    if reduceMotion {
                                        showResultSheet = true
                                    } else {
                                        withAnimation(.spring(response: 0.4)) {
                                            showResultSheet = true
                                        }
                                    }
                                }
                            }
                            
                            // Game Center reporting
                            reportToGameCenter()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                } else if viewModel.gameState == .gaveUp {
                    ArchiveGaveUpOverlay(viewModel: viewModel, dismiss: dismiss)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !viewModel.isDaily {
                    ArchiveLocalResultOverlay(viewModel: viewModel, dismiss: dismiss)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showResultSheet) {
            ArchiveResultSheet(viewModel: viewModel, showResultSheet: $showResultSheet)
        }
        .alert("Give Up?", isPresented: $showGiveUpAlert) {
            Button("Give Up", role: .destructive) {
                viewModel.giveUp()
                if !viewModel.isDaily || PersistenceManager.fetchDailyResult(for: .archive, on: .now, context: modelContext) == nil {
                    let result = viewModel.buildGameResult()
                    PersistenceManager.save(result, context: modelContext)
                }
                if let lvl = viewModel.activeLevelId {
                    PersistenceManager.markLevelPlayed(
                        gameType: .archive, levelId: lvl, won: false,
                        score: 0, guessesUsed: viewModel.guessCount,
                        durationSeconds: Date.now.timeIntervalSince(viewModel.startDate),
                        context: modelContext
                    )
                }
                Haptics.playMediumImpact()
            }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text("You'll be able to see the answer.")
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .showTutorialOnFirstPlay(for: .archive)
        .onChange(of: viewModel.showInvalidShake) { old, new in
            if new { Haptics.playError() }
        }
    }
    }
    
// MARK: - Subviews

struct ArchiveLocalResultOverlay: View {
    let viewModel: ArchiveGameViewModel
    let dismiss: DismissAction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let didWin = viewModel.gameState.isCompleted
        
        return ResultOverlayTemplate(
            style: .panel,
            header: .custom(
                title: didWin ? "DATE CRACKED!" : "TIME'S UP",
                subtitle: "\(viewModel.secretEvent.event) (\(viewModel.secretEvent.dateString))"
            ),
            stats: []
        ) {
            EmptyView()
        } actions: {
            HStack(spacing: 16) {
                ResultPrimaryButton(title: viewModel.activeLevelId == 100 ? "All Done" : "Done") {
                    dismiss()
                }

                if let levelId = viewModel.activeLevelId, levelId < 100 {
                    ResultPrimaryButton(title: "Next Level") {
                        if reduceMotion {
                            viewModel.loadLevel(levelId + 1)
                        } else {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                viewModel.loadLevel(levelId + 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ArchiveGaveUpOverlay: View {
    let viewModel: ArchiveGameViewModel
    let dismiss: DismissAction

    var body: some View {
        ResultOverlayTemplate(
            style: .panel,
            header: .iconTitle(icon: "flag.fill", color: .red.opacity(0.7), title: "GAVE UP"),
            stats: []
        ) {
            // Show the answer
            VStack(spacing: 6) {
                Text(viewModel.solutionEvent.event)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(viewModel.solutionEvent.dateString)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.archive)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.06)))
        } actions: {
            HStack(spacing: 16) {
                ResultSecondaryButton(title: "Try Again") {
                    viewModel.reset()
                }
                ResultPrimaryButton(title: "Done") {
                    dismiss()
                }
            }
        }
    }
}

struct ArchiveHeader: View {
    let viewModel: ArchiveGameViewModel
    let dismiss: DismissAction
    @Binding var showGiveUpAlert: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Text("ARCHIVE")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.shift,
                                     AppTheme.cascadeBlue],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()

                    if viewModel.gameState == .inProgress {
                        Button {
                            showGiveUpAlert = true
                        } label: {
                            Label("Give Up", systemImage: "flag.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                        }
                        .padding(.trailing, 12)
                    }
                }
            }

            ArchiveCounterPill(guessCount: viewModel.guessCount, maxGuesses: viewModel.maxGuesses)
                .padding(.top, 2)

            if AppSettings.showGameTimer {
                ArchiveTimerPill(timerString: viewModel.timerString)
                    .padding(.top, 2)
            }

            // Hint text
            Text("\u{201C}\(viewModel.secretEvent.hint)\u{201D}")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ArchiveCounterPill: View {
    let guessCount: Int
    let maxGuesses: Int

    var body: some View {
        let label = Text("\(guessCount) / \(maxGuesses)")
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 5)

        if #available(iOS 26, *) {
            label
                .glassEffect(.regular, in: Capsule())
        } else {
            label
                .background(Capsule().fill(AppTheme.pillFill))
        }
    }
}

struct ArchiveTimerPill: View {
    let timerString: String

    var body: some View {
        let label = HStack(spacing: 4) {
            Image(systemName: "clock").font(.system(size: 10, weight: .bold))
            Text(timerString).font(.system(size: 12, weight: .bold, design: .monospaced))
        }
            .foregroundStyle(.primary.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

        if #available(iOS 26, *) {
            label.glassEffect(.regular, in: Capsule())
        } else {
            label.background(Capsule().fill(AppTheme.pillFill))
        }
    }
}

struct ArchiveBoard: View {
    let viewModel: ArchiveGameViewModel

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<viewModel.maxGuesses, id: \.self) { rowIndex in
                if rowIndex < viewModel.guessHistory.count {
                    let entry = viewModel.guessHistory[rowIndex]
                    ArchiveFeedbackRow(guess: entry.guess, feedback: entry.feedback)
                        .id(rowIndex)
                } else if rowIndex == viewModel.guessHistory.count && !viewModel.gameState.isOver {
                    ArchiveActiveInputRow(currentInput: viewModel.currentInput)
                        .modifier(ShakeEffect(shakes: viewModel.showInvalidShake ? 3 : 0))
                        .animation(.easeInOut(duration: 0.4), value: viewModel.showInvalidShake)
                } else {
                    ArchiveEmptyRow()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.guessCount)
    }
}

struct ArchiveActiveInputRow: View {
    let currentInput: [Int?]

    private var firstEmptyInputSlot: Int {
        currentInput.firstIndex(of: nil) ?? 8
    }

    var body: some View {
        HStack(spacing: 0) {
            ArchiveDigitInputGroup(currentInput: currentInput, firstEmptyInputSlot: firstEmptyInputSlot, range: 0..<2)
            ArchiveInputSeparator()
            ArchiveDigitInputGroup(currentInput: currentInput, firstEmptyInputSlot: firstEmptyInputSlot, range: 2..<4)
            ArchiveInputSeparator()
            ArchiveDigitInputGroup(currentInput: currentInput, firstEmptyInputSlot: firstEmptyInputSlot, range: 4..<8)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.12), value: currentInput.map { $0 ?? -1 })
    }
}

struct ArchiveDigitInputGroup: View {
    let currentInput: [Int?]
    let firstEmptyInputSlot: Int
    let range: Range<Int>

    var body: some View {
        HStack(spacing: 4) {
            ForEach(range, id: \.self) { index in
                ArchiveActiveCell(
                    digit: currentInput[index],
                    isNextEmpty: currentInput[index] == nil && index == firstEmptyInputSlot
                )
            }
        }
    }
}

struct ArchiveInputSeparator: View {
    var body: some View {
        Text("/")
            .font(.system(size: 16, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.25))
            .frame(width: 14)
    }
}

struct ArchiveEmptyRow: View {
    var body: some View {
        HStack(spacing: 0) {
            ArchiveEmptyGroup(count: 2)
            ArchiveEmptySeparator()
            ArchiveEmptyGroup(count: 2)
            ArchiveEmptySeparator()
            ArchiveEmptyGroup(count: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ArchiveEmptyGroup: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(AppTheme.cellBorder, lineWidth: 1.5)
                    .frame(width: 36, height: 42)
            }
        }
    }
}

struct ArchiveEmptySeparator: View {
    var body: some View {
        Text("/")
            .font(.system(size: 16, weight: .semibold, design: .monospaced))
            .foregroundStyle(AppTheme.dimText)
            .frame(width: 14)
    }
}

struct ArchiveResultSheet: View {
    let viewModel: ArchiveGameViewModel
    @Binding var showResultSheet: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            let didWin = viewModel.gameState.isCompleted
            Image(systemName: didWin ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(didWin
                    ? AppTheme.signals
                    : AppTheme.error)
                .symbolEffect(.bounce, value: showResultSheet)

            Text(didWin ? "Date Cracked!" : "Time's Up")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)

            // Show event name and date
            VStack(spacing: 6) {
                Text(viewModel.secretEvent.event)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(viewModel.secretEvent.dateString)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if viewModel.isDaily {
                let shareString = viewModel.generateShareString()
                ShareLink(item: shareString) {
                    Label("Share Result", systemImage: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            } else {
                Button("Done") {
                    showResultSheet = false
                }
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [AppTheme.shift,
                                     AppTheme.cascadeBlue],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
                .foregroundStyle(.primary)
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.fraction(0.55)])
        .presentationCornerRadius(24)
    }
}

// MARK: - Active Cell with Bounce

private struct ArchiveActiveCell: View {
    let digit: Int?
    let isNextEmpty: Bool

    @State private var scale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    digit != nil
                        ? Color.primary.opacity(0.80)
                        : (isNextEmpty ? Color.primary.opacity(0.50) : AppTheme.cellBorder),
                    lineWidth: isNextEmpty && digit == nil ? 2 : 1.5
                )
                .frame(width: 36, height: 42)

            if let d = digit {
                Text("\(d)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .scaleEffect(scale)
        .onChange(of: digit) { old, new in
            guard old == nil, new != nil else { return }
            guard !reduceMotion else {
                scale = 1.0
                return
            }
            withAnimation(.spring(response: 0.12, dampingFraction: 0.45)) {
                scale = 1.12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) {
                    scale = 1.0
                }
            }
        }
    }
}

// MARK: - Shake Effect

private struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var animatableData: CGFloat {
        get { CGFloat(shakes) }
        set { shakes = Int(newValue) }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = sin(animatableData * .pi * 2) * 8
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

// MARK: - Game Center Reporting

extension ArchiveGameView {
    private func reportToGameCenter() {
        let gc = GameCenterManager.shared
        let didWin = viewModel.gameState.isCompleted

        // Achievement: first archive puzzle completed (win or lose)
        gc.reportAchievement(GameCenterManager.Achievement.firstArchive)

        if viewModel.isDaily && didWin {
            // Daily best score (fewer guesses = better)
            gc.submitScore(viewModel.guessCount,
                           leaderboardIDs: [GameCenterManager.Leaderboard.archiveDailyBest])

            // Update streak and submit
            let streak = StreakManager.recordDailyWin(game: "archive")
            gc.submitScore(streak,
                           leaderboardIDs: [GameCenterManager.Leaderboard.archiveDailyStreak])

            // Streak achievements
            if streak >= 3  { gc.reportAchievement(GameCenterManager.Achievement.streak3) }
            if streak >= 7  { gc.reportAchievement(GameCenterManager.Achievement.streak7) }
            if streak >= 30 { gc.reportAchievement(GameCenterManager.Achievement.streak30) }
        }

        if !viewModel.isDaily && didWin {
            // Count all won local levels across both games for mastery
            let totalWon = PersistenceManager.totalLocalWins(context: modelContext)
            gc.submitScore(totalWon,
                           leaderboardIDs: [GameCenterManager.Leaderboard.localMastery])

            gc.reportProgressAchievement(GameCenterManager.Achievement.local25, current: totalWon, target: 25)
            gc.reportProgressAchievement(GameCenterManager.Achievement.local50, current: totalWon, target: 50)
            gc.reportProgressAchievement(GameCenterManager.Achievement.local100, current: totalWon, target: 100)
        }
    }
}

// MARK: - Previews

#Preview("Daily — In Progress") {
    ArchiveGameView()
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}

#Preview("Mid-game") {
    let vm = ArchiveGameViewModel(date: .now)
    // Override with a known event for testing
    let testEvent = ArchiveEvent(id: 99, day: 20, month: 7, year: 1969,
                                  hint: "One small step changed it all",
                                  event: "Apollo 11 Moon Landing")
    vm.overrideForTesting(event: testEvent, maxGuesses: 7)
    vm.currentInput = [1, 5, 0, 4, 1, 9, 1, 2]; vm.submitGuess()
    vm.currentInput = [2, 0, 0, 7, 1, 9, 5, 0]; vm.submitGuess()
    return ArchiveGameView(viewModel: vm)
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}

#Preview("Completed — Win") {
    let vm = ArchiveGameViewModel(date: .now)
    let testEvent = ArchiveEvent(id: 99, day: 20, month: 7, year: 1969,
                                  hint: "One small step changed it all",
                                  event: "Apollo 11 Moon Landing")
    vm.overrideForTesting(event: testEvent, maxGuesses: 7)
    vm.currentInput = [1, 5, 0, 4, 1, 9, 1, 2]; vm.submitGuess()
    vm.currentInput = [2, 0, 0, 7, 1, 9, 6, 9]; vm.submitGuess()
    return ArchiveGameView(viewModel: vm)
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}
