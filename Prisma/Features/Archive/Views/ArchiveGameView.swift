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

struct ArchiveGameView: View {
    @State private var viewModel: ArchiveGameViewModel
    @State private var showResultSheet = false
    @State private var showGiveUpAlert = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ArchiveGameViewModel = ArchiveGameViewModel(date: .now)) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Background
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08)
                RadialGradient(
                    colors: [Color(red: 0.15, green: 0.08, blue: 0.3).opacity(0.4), .clear],
                    center: .top, startRadius: 50, endRadius: 500
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                board
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
                                    context: modelContext
                                )
                            }
                            // Save GameResult for both daily and local games to enable history display
                            let result = viewModel.buildGameResult()
                            PersistenceManager.save(result, context: modelContext)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
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
                    archiveGaveUpOverlay
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
                        gameType: .archive, levelId: lvl, won: false,
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
        .navigationBarBackButtonHidden(true)
        .showTutorialOnFirstPlay(for: .archive)
        .onChange(of: viewModel.showInvalidShake) { old, new in
            if new { Haptics.playError() }
        }
    }

    // MARK: - Local Result Overlay

    private var localResultOverlay: some View {
        VStack(spacing: 20) {
            let didWin = viewModel.gameState.isCompleted
            
            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: didWin ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(didWin ? Color(red: 0.24, green: 0.65, blue: 0.36) : Color(red: 0.85, green: 0.30, blue: 0.30))
                    
                    Text(didWin ? "DATE CRACKED!" : "TIME'S UP")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                Text("\(viewModel.secretEvent.event) (\(viewModel.secretEvent.dateString))")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.06)))

            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Text(viewModel.activeLevelId == 100 ? "All Done" : "Done")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color(red: 0.65, green: 0.24, blue: 0.85),
                                             Color(red: 0.4, green: 0.6, blue: 1.0)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                        )
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
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.65, green: 0.24, blue: 0.85),
                                                 Color(red: 0.4, green: 0.6, blue: 1.0)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                            )
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    // MARK: - Gave Up Overlay

    private var archiveGaveUpOverlay: some View {
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

            // Show the answer
            VStack(spacing: 6) {
                Text(viewModel.solutionEvent.event)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(viewModel.solutionEvent.dateString)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.24, green: 0.52, blue: 0.85))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))

            HStack(spacing: 16) {
                Button {
                    viewModel.reset()
                } label: {
                    Text("Try Again")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color(red: 0.65, green: 0.24, blue: 0.85),
                                             Color(red: 0.4, green: 0.6, blue: 1.0)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                        )
                        .foregroundStyle(.white)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color(red: 0.65, green: 0.24, blue: 0.85),
                                             Color(red: 0.4, green: 0.6, blue: 1.0)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                        )
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            ZStack {
                Text("ARCHIVE")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.65, green: 0.24, blue: 0.85),
                                     Color(red: 0.4, green: 0.6, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                
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

            // Hint text
            Text("\u{201C}\(viewModel.secretEvent.hint)\u{201D}")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }

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
        VStack(spacing: 6) {
            ForEach(0..<viewModel.maxGuesses, id: \.self) { rowIndex in
                if rowIndex < viewModel.guessHistory.count {
                    let entry = viewModel.guessHistory[rowIndex]
                    ArchiveFeedbackRow(guess: entry.guess, feedback: entry.feedback)
                        .id(rowIndex)
                } else if rowIndex == viewModel.guessHistory.count && !viewModel.gameState.isOver {
                    activeInputRow
                        .modifier(ShakeEffect(shakes: viewModel.showInvalidShake ? 3 : 0))
                        .animation(.easeInOut(duration: 0.4), value: viewModel.showInvalidShake)
                } else {
                    emptyRow
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.guessCount)
    }

    // MARK: - Active Input Row

    private var activeInputRow: some View {
        HStack(spacing: 0) {
            digitInputGroup(range: 0..<2)
            inputSeparator
            digitInputGroup(range: 2..<4)
            inputSeparator
            digitInputGroup(range: 4..<8)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.12), value: viewModel.currentInput.map { $0 ?? -1 })
    }

    @ViewBuilder
    private func digitInputGroup(range: Range<Int>) -> some View {
        HStack(spacing: 4) {
            ForEach(range, id: \.self) { index in
                ArchiveActiveCell(
                    digit: viewModel.currentInput[index],
                    isNextEmpty: viewModel.currentInput[index] == nil
                        && index == firstEmptyInputSlot
                )
            }
        }
    }

    private var inputSeparator: some View {
        Text("/")
            .font(.system(size: 16, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.25))
            .frame(width: 14)
    }

    private var firstEmptyInputSlot: Int {
        viewModel.currentInput.firstIndex(of: nil) ?? 8
    }

    // MARK: - Empty Row

    private var emptyRow: some View {
        HStack(spacing: 0) {
            emptyGroup(count: 2)
            emptySeparator
            emptyGroup(count: 2)
            emptySeparator
            emptyGroup(count: 4)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func emptyGroup(count: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1.5)
                    .frame(width: 36, height: 42)
            }
        }
    }

    private var emptySeparator: some View {
        Text("/")
            .font(.system(size: 16, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.10))
            .frame(width: 14)
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
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(red: 0.65, green: 0.24, blue: 0.85),
                                     Color(red: 0.4, green: 0.6, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
                .foregroundStyle(.white)
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    digit != nil
                        ? Color.white.opacity(0.80)
                        : (isNextEmpty ? Color.white.opacity(0.50) : Color.white.opacity(0.18)),
                    lineWidth: isNextEmpty && digit == nil ? 2 : 1.5
                )
                .frame(width: 36, height: 42)

            if let d = digit {
                Text("\(d)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .scaleEffect(scale)
        .onChange(of: digit) { old, new in
            guard old == nil, new != nil else { return }
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
        // let gc = GameCenterManager.shared
        // let didWin = viewModel.gameState.isCompleted

        // // Achievement: first archive puzzle completed (win or lose)
        // gc.reportAchievement(GameCenterManager.Achievement.firstArchive)

        // if viewModel.isDaily && didWin {
        //     // Daily best score (fewer guesses = better)
        //     gc.submitScore(viewModel.guessCount,
        //                    leaderboardIDs: [GameCenterManager.Leaderboard.archiveDailyBest])

        //     // Update streak
        //     let streak = StreakManager.recordDailyWin(game: "archive")
        //     gc.submitScore(streak,
        //                    leaderboardIDs: [GameCenterManager.Leaderboard.archiveDailyStreak])

        //     // Streak achievements
        //     if streak >= 3  { gc.reportAchievement(GameCenterManager.Achievement.streak3) }
        //     if streak >= 7  { gc.reportAchievement(GameCenterManager.Achievement.streak7) }
        //     if streak >= 30 { gc.reportAchievement(GameCenterManager.Achievement.streak30) }
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
