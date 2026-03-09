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

struct SignalsGameView: View {
    @State private var viewModel: SignalsGameViewModel
    @State private var showResultSheet = false
    @State private var showGiveUpAlert = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SignalsGameViewModel = SignalsGameViewModel(date: .now)) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 4)
                    .padding(.bottom, 14)

                board
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
                                    context: modelContext
                                )
                            }
                            
                            // Save GameResult for both daily and local games to enable history display
                            let result = viewModel.buildGameResult()
                            PersistenceManager.save(result, context: modelContext)
                            
                            // Delayed haptics/flow
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                                if viewModel.gameState.isCompleted { Haptics.playSuccess() }
                                else { Haptics.playMediumImpact() }
                                
                                if viewModel.isDaily {
                                    withAnimation(.spring(response: 0.4)) {
                                        showResultSheet = true
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
                    signalsGaveUpOverlay
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !viewModel.isDaily {
                    localResultOverlay
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showResultSheet) {
            resultSheet
        }
        .alert("Give Up?", isPresented: $showGiveUpAlert) {
            Button("Give Up", role: .destructive) {
                viewModel.giveUp()
                let result = viewModel.buildGameResult()
                PersistenceManager.save(result, context: modelContext)
                if let lvl = viewModel.activeLevelId {
                    PersistenceManager.markLevelPlayed(
                        gameType: .signals, levelId: lvl, won: false,
                        score: 0, guessesUsed: viewModel.guessCount, context: modelContext
                    )
                }
                Haptics.playMediumImpact()
            }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text("You'll be able to see the answer.")
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(viewModel.gameState.isOver && !viewModel.isDaily)
        .showTutorialOnFirstPlay(for: .signals)
    }

    // MARK: - Local Result Overlay

    private var localResultOverlay: some View {
        VStack(spacing: 20) {
            let didWin = viewModel.gameState.isCompleted
            
            HStack(spacing: 12) {
                Image(systemName: didWin ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(didWin ? Color(red: 0.24, green: 0.65, blue: 0.36) : Color(red: 0.85, green: 0.30, blue: 0.30))
                
                Text(didWin ? "LEVEL \(viewModel.activeLevelId ?? 0) COMPLETED" : "SIGNAL LOST")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Capsule().fill(Color.white.opacity(0.08)))

            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Text(viewModel.activeLevelId == 100 ? "All Done" : "Done")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.12)))
                        .foregroundStyle(.white)
                }

                if let levelId = viewModel.activeLevelId, levelId < 100 {
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            viewModel.loadLevel(levelId + 1)
                        }
                    } label: {
                        Text("Next Level")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                            .foregroundStyle(.black)
                    }
                }
            }
        }
    }

    // MARK: - Gave Up Overlay

    private var signalsGaveUpOverlay: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.red.opacity(0.7))
                Text("GAVE UP")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Capsule().fill(Color.white.opacity(0.08)))

            // Show the secret code
            VStack(spacing: 6) {
                Text("The code was:")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 8) {
                    ForEach(viewModel.solutionDigits, id: \.self) { digit in
                        Text("\(digit)")
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(red: 0.24, green: 0.65, blue: 0.36).opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Color(red: 0.24, green: 0.65, blue: 0.36).opacity(0.6), lineWidth: 1.5)
                                    )
                            )
                    }
                }
            }

            HStack(spacing: 16) {
                Button {
                    viewModel.reset()
                } label: {
                    Text("Try Again")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.12)))
                        .foregroundStyle(.white)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                        .foregroundStyle(.black)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            ZStack {
                Text("SIGNALS")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .kerning(3)
                
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(8)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()

                    if viewModel.gameState == .inProgress {
                        Button {
                            showGiveUpAlert = true
                        } label: {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.red.opacity(0.5))
                                .padding(8)
                        }
                    }
                    
                    Button {
                        viewModel.reset()
                        Haptics.playMediumImpact()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(8)
                    }
                    .padding(.trailing, 12)
                }
            }

            counterPill
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    /// Guess counter pill — liquid glass on iOS 26, frosted capsule on iOS 18.
    @ViewBuilder
    private var counterPill: some View {
        let label = Text("\(viewModel.guessCount) / \(viewModel.maxGuesses)")
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 5)

        if #available(iOS 26, *) {
            label
                .glassEffect(.regular, in: Capsule())
        } else {
            label
                .background(Capsule().fill(Color.white.opacity(0.12)))
        }
    }

    // MARK: - Board

    private var board: some View {
        VStack(spacing: 8) {
            ForEach(0..<viewModel.maxGuesses, id: \.self) { rowIndex in
                if rowIndex < viewModel.guessHistory.count {
                    let entry = viewModel.guessHistory[rowIndex]
                    SignalsFeedbackRow(guess: entry.guess, feedback: entry.feedback)
                        .id(rowIndex) // stable identity so flip triggers once per guess
                } else if rowIndex == viewModel.guessHistory.count && !viewModel.gameState.isOver {
                    activeInputRow
                } else {
                    emptyRow
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.guessCount)
    }

    // MARK: - Active Input Row

    private var activeInputRow: some View {
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

    // MARK: - Empty Row

    private var emptyRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 2)
                    .frame(width: 58, height: 58)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Result Sheet

    private var resultSheet: some View {
        VStack(spacing: 20) {
            Spacer()

            let didWin = viewModel.gameState.isCompleted
            Image(systemName: didWin ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(didWin
                    ? Color(red: 0.24, green: 0.65, blue: 0.36)
                    : Color(red: 0.85, green: 0.30, blue: 0.30))
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
                        .foregroundStyle(.white)
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
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.18)))
                .foregroundStyle(.white)
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

// MARK: - Active Cell with Bounce

/// A single input slot in the active guess row.
/// Springs to 1.12× scale when a digit lands, then settles back to 1.0.
private struct SignalsActiveCell: View {
    let digit: Int?
    let isNextEmpty: Bool

    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    digit != nil
                        ? Color.white.opacity(0.80)
                        : (isNextEmpty ? Color.white.opacity(0.50) : Color.white.opacity(0.18)),
                    lineWidth: isNextEmpty && digit == nil ? 2.5 : 2
                )
                .frame(width: 58, height: 58)

            if let d = digit {
                Text("\(d)")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .scaleEffect(scale)
        .onChange(of: digit) { old, new in
            guard old == nil, new != nil else { return }
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

// MARK: - Game Center Reporting

extension SignalsGameView {
    private func reportToGameCenter() {
        // let gc = GameCenterManager.shared
        // let didWin = viewModel.gameState.isCompleted

        // // Achievement: first signal puzzle completed (win or lose)
        // gc.reportAchievement(GameCenterManager.Achievement.firstSignal)

        // if viewModel.isDaily && didWin {
        //     // Daily best score (fewer guesses = better)
        //     gc.submitScore(viewModel.guessCount,
        //                    leaderboardIDs: [GameCenterManager.Leaderboard.signalsDailyBest])

        //     // Update streak
        //     let streak = StreakManager.recordDailyWin(game: "signals")
        //     gc.submitScore(streak,
        //                    leaderboardIDs: [GameCenterManager.Leaderboard.signalsDailyStreak])

        //     // Streak achievements
        //     if streak >= 3  { gc.reportAchievement(GameCenterManager.Achievement.streak3) }
        //     if streak >= 7  { gc.reportAchievement(GameCenterManager.Achievement.streak7) }
        //     if streak >= 30 { gc.reportAchievement(GameCenterManager.Achievement.streak30) }

        //     // Perfect score (1 guess)
        //     if viewModel.guessCount == 1 {
        //         gc.reportAchievement(GameCenterManager.Achievement.perfectSignal)
        //     }
        // }

        // if !viewModel.isDaily && didWin {
        //     // Count all won local levels across both games for mastery
        //     let totalWon = PersistenceManager.totalLocalWins(context: modelContext)
        //     gc.submitScore(totalWon,
        //                    leaderboardIDs: [GameCenterManager.Leaderboard.localMastery])

        //     gc.reportProgressAchievement(GameCenterManager.Achievement.local25, current: totalWon, target: 25)
        //     gc.reportProgressAchievement(GameCenterManager.Achievement.local50, current: totalWon, target: 50)
        //     gc.reportProgressAchievement(GameCenterManager.Achievement.local100, current: totalWon, target: 100)
        // }
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
