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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ArchiveGameViewModel = ArchiveGameViewModel(date: .now)) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.10)
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                if viewModel.gameState.isCompleted { Haptics.playSuccess() }
                                else { Haptics.playMediumImpact() }
                                
                                if viewModel.isDaily {
                                    withAnimation(.spring(response: 0.4)) {
                                        showResultSheet = true
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
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
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(viewModel.gameState.isOver && !viewModel.isDaily)
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("ARCHIVE")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .kerning(3)

            counterPill
                .padding(.top, 2)

            // Hint text
            Text("\u{201C}\(viewModel.secretEvent.hint)\u{201D}")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 32)
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
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.18)))
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
