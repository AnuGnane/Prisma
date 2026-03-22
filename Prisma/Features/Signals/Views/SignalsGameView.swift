//
//  SignalsGameView.swift
//  Prisma
//
//  Main container for a Signals game session.
//  Board: fixed maxGuesses rows — past guesses flip-reveal feedback,
//  the current row shows live input with digit-pop spring animation,
//  future rows are empty placeholders.
//  Header counter pill uses iOS 26 glassEffect when available, capsule fill on iOS 18.
//

import SwiftUI
import SwiftData

@MainActor
struct SignalsGameView: View {
    @State private var viewModel: SignalsGameViewModel
    @State private var showResultSheet = false
    @State private var showGiveUpAlert = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: SignalsGameViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    init() {
        _viewModel = State(initialValue: SignalsGameViewModel(date: .now))
    }

    var body: some View {
        ZStack {
            // Background
            AppTheme.appBackground()

            VStack(spacing: 0) {
                SignalsHeader(viewModel: viewModel, showGiveUpAlert: $showGiveUpAlert)
                    .padding(.top, 4)
                    .padding(.bottom, 14)

                SignalsBoard(viewModel: viewModel)
                    .padding(.horizontal, 24)

                Spacer(minLength: 8)

                if !viewModel.gameState.isOver {
                    SignalsInputView(viewModel: viewModel) {
                        viewModel.submitGuess()
                        if viewModel.gameState.isOver {
                            // Save local level progress (win or loss)
                            if let levelId = viewModel.activeLevelId {
                                let didWin = viewModel.gameState.isCompleted
                                let score: Int
                                if case .completed(let s) = viewModel.gameState { score = s } else { score = 0 }
                                PersistenceManager.markLevelPlayed(
                                    gameType: .signals,
                                    levelId: levelId,
                                    won: didWin,
                                    score: score,
                                    guessesUsed: viewModel.guessCount,
                                    durationSeconds: Date.now.timeIntervalSince(viewModel.startDate),
                                    context: modelContext
                                )
                            }
                            
                            // Save GameResult (prevent duplicate daily saves)
                            if !viewModel.isDaily || PersistenceManager.fetchDailyResult(for: .signals, on: .now, context: modelContext) == nil {
                                let result = viewModel.buildGameResult()
                                PersistenceManager.save(result, context: modelContext)
                            }
                            
                            // Delayed haptics/flow
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
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
                    SignalsGaveUpOverlay(viewModel: viewModel, dismiss: { dismiss() })
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !viewModel.isDaily {
                    SignalsLocalResultOverlay(viewModel: viewModel, reduceMotion: reduceMotion, dismiss: { dismiss() })
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showResultSheet) {
            SignalsResultSheet(viewModel: viewModel, showResultSheet: $showResultSheet)
        }
        .alert("Give Up?", isPresented: $showGiveUpAlert) {
            Button("Give Up", role: .destructive) {
                viewModel.giveUp()
                if !viewModel.isDaily || PersistenceManager.fetchDailyResult(for: .signals, on: .now, context: modelContext) == nil {
                    let result = viewModel.buildGameResult()
                    PersistenceManager.save(result, context: modelContext)
                }
                if let lvl = viewModel.activeLevelId {
                    PersistenceManager.markLevelPlayed(
                        gameType: .signals, levelId: lvl, won: false,
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
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .showTutorialOnFirstPlay(for: .signals)
    }

    // MARK: - Game Center Reporting

}

// MARK: - Subviews

struct SignalsHeader: View {
    let viewModel: SignalsGameViewModel
    @Binding var showGiveUpAlert: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Text("SIGNALS")
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

            SignalsCounterPill(viewModel: viewModel)
                .padding(.top, 2)

            if AppSettings.showGameTimer {
                SignalsTimerPill(viewModel: viewModel)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SignalsCounterPill: View {
    let viewModel: SignalsGameViewModel

    var body: some View {
        let label = Text("\(viewModel.guessCount) / \(viewModel.maxGuesses)")
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

struct SignalsTimerPill: View {
    let viewModel: SignalsGameViewModel

    var body: some View {
        let label = HStack(spacing: 4) {
            Image(systemName: "clock").font(.system(size: 10, weight: .bold))
            Text(viewModel.timerString).font(.system(size: 12, weight: .bold, design: .monospaced))
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

struct SignalsBoard: View {
    let viewModel: SignalsGameViewModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<viewModel.maxGuesses, id: \.self) { rowIndex in
                if rowIndex < viewModel.guessHistory.count {
                    let entry = viewModel.guessHistory[rowIndex]
                    SignalsFeedbackRow(guess: entry.guess, feedback: entry.feedback)
                        .id(rowIndex) // stable identity so flip triggers once per guess
                } else if rowIndex == viewModel.guessHistory.count && !viewModel.gameState.isOver {
                    SignalsActiveInputRow(viewModel: viewModel)
                } else {
                    SignalsEmptyRow()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.guessCount)
    }
}

struct SignalsActiveInputRow: View {
    let viewModel: SignalsGameViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                SignalsActiveCell(
                    digit: viewModel.currentInput[index],
                    isNextEmpty: viewModel.currentInput[index] == nil
                        && index == firstEmptyInputSlot
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var firstEmptyInputSlot: Int {
        viewModel.currentInput.firstIndex(of: nil) ?? 4
    }
}

struct SignalsEmptyRow: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(AppTheme.cellBorder, lineWidth: 2)
                    .frame(width: 58, height: 58)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SignalsResultSheet: View {
    let viewModel: SignalsGameViewModel
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

            Text(didWin ? "Signal Locked!" : "Signal Lost")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)

            if !didWin {
                let secret = viewModel.secretCode.digits.map { "\($0)" }.joined(separator: " ")
                Text("The code was: \(secret)")
                    .font(.system(size: 15))
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
        .presentationDetents([.fraction(0.50)])
        .presentationCornerRadius(24)
    }
}

struct SignalsLocalResultOverlay: View {
    let viewModel: SignalsGameViewModel
    let reduceMotion: Bool
    let dismiss: () -> Void

    var body: some View {
        let didWin = viewModel.gameState.isCompleted
        
        return ResultOverlayTemplate(
            style: .panel,
            header: .iconTitle(
                icon: didWin ? "checkmark.circle.fill" : "xmark.circle.fill",
                color: didWin ? AppTheme.signals : AppTheme.error,
                title: didWin ? "LEVEL \(viewModel.activeLevelId ?? 0) COMPLETED" : "SIGNAL LOST"
            ),
            stats: []
        ) {
            EmptyView()
        } actions: {
            HStack(spacing: 16) {
                ResultSecondaryButton(title: viewModel.activeLevelId == 100 ? "All Done" : "Done") {
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

struct SignalsGaveUpOverlay: View {
    let viewModel: SignalsGameViewModel
    let dismiss: () -> Void

    var body: some View {
        ResultOverlayTemplate(
            style: .panel,
            header: .iconTitle(icon: "flag.fill", color: .red.opacity(0.7), title: "GAVE UP"),
            stats: []
        ) {
            // Show the secret code
            VStack(spacing: 6) {
                Text("The code was:")
                    .font(.system(size: 13)).foregroundStyle(.primary.opacity(0.5))
                HStack(spacing: 8) {
                    ForEach(viewModel.solutionDigits, id: \.self) { digit in
                        Text("\(digit)")
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppTheme.signals.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(AppTheme.signals.opacity(0.6), lineWidth: 1.5)
                                    )
                            )
                    }
                }
            }
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

// MARK: - Game Center Reporting

/// A single input slot in the active guess row.
/// Springs to 1.12× scale when a digit lands, then settles back to 1.0.
private struct SignalsActiveCell: View {
    let digit: Int?
    let isNextEmpty: Bool

    @State private var scale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    digit != nil
                        ? Color.primary.opacity(0.80)
                        : (isNextEmpty ? Color.primary.opacity(0.50) : AppTheme.cellBorder),
                    lineWidth: isNextEmpty && digit == nil ? 2.5 : 2
                )
                .frame(width: 58, height: 58)

            if let d = digit {
                Text("\(d)")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
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
            // Spring pop: scale up then settle back
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

extension SignalsGameView {
    private func reportToGameCenter() {
        let gc = GameCenterManager.shared
        let didWin = viewModel.gameState.isCompleted

        // Achievement: first signal puzzle completed (win or lose)
        gc.reportAchievement(GameCenterManager.Achievement.firstSignal)

        if viewModel.isDaily && didWin {
            // Daily best score (fewer guesses = better)
            gc.submitScore(viewModel.guessCount,
                           leaderboardIDs: [GameCenterManager.Leaderboard.signalsDailyBest])

            // Update streak and submit
            let streak = StreakManager.recordDailyWin(game: "signals")
            gc.submitScore(streak,
                           leaderboardIDs: [GameCenterManager.Leaderboard.signalsDailyStreak])

            // Streak achievements
            if streak >= 3  { gc.reportAchievement(GameCenterManager.Achievement.streak3) }
            if streak >= 7  { gc.reportAchievement(GameCenterManager.Achievement.streak7) }
            if streak >= 30 { gc.reportAchievement(GameCenterManager.Achievement.streak30) }

            // Perfect score (1 guess)
            if viewModel.guessCount == 1 {
                gc.reportAchievement(GameCenterManager.Achievement.perfectSignal)
            }
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
    SignalsGameView()
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}

#Preview("Mid-game with key states") {
    let vm = SignalsGameViewModel(date: .now)
    vm.overrideForTesting(secret: SignalsCode(digits: [1, 2, 3, 4]), maxGuesses: 5)
    vm.currentInput = [9, 9, 9, 9]; vm.submitGuess()
    vm.currentInput = [5, 1, 7, 8]; vm.submitGuess()
    return SignalsGameView(viewModel: vm)
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}

#Preview("Completed") {
    let vm = SignalsGameViewModel(date: .now)
    vm.overrideForTesting(secret: SignalsCode(digits: [1, 2, 3, 4]), maxGuesses: 5)
    vm.currentInput = [9, 9, 9, 9]; vm.submitGuess()
    vm.currentInput = [1, 2, 3, 4]; vm.submitGuess()
    return SignalsGameView(viewModel: vm)
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}
