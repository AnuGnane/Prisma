//
//  ShiftGameView.swift
//  Prisma
//
//  Main game view for Shift v3 — clean, no par/hints.
//

import SwiftUI
import SwiftData

struct ShiftGameView: View {
    @State private var viewModel: ShiftGameViewModel
    @State private var showGiveUpAlert = false
    @State private var moveCountBounce = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(puzzle: ShiftPuzzle, isDaily: Bool, levelId: Int? = nil) {
        _viewModel = State(initialValue: ShiftGameViewModel(
            puzzle: puzzle, isDaily: isDaily, levelId: levelId
        ))
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
                gameHeader
                    .padding(.top, 4)
                    .padding(.bottom, 6)

                // Target words — fixed height container
                TargetWordListView(
                    targetWords: viewModel.puzzle.targetWords,
                    completedWords: viewModel.completedWords,
                    hintWord: nil
                )
                .frame(height: 80, alignment: .top)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

                // Grid — solution or interactive
                if viewModel.showingSolution, let solGrid = viewModel.solutionGrid {
                    solutionGridSection(solGrid)
                        .padding(.top, 4)
                } else {
                    ShiftGridView(
                        grid: Binding(
                            get: { viewModel.currentGrid },
                            set: { viewModel.currentGrid = $0 }
                        ),
                        highlightedCells: viewModel.highlightedCells,
                        hintCells: [],
                        interactive: viewModel.gameState == .inProgress,
                        onMove: { move in
                            viewModel.performMove(move)
                        }
                    )
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }

                Spacer(minLength: 4)

                controls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            // Completion overlay
            if case .completed(let score) = viewModel.gameState {
                completionOverlay(score: score)
            }

            // Gave up overlay
            if viewModel.gameState == .gaveUp && !viewModel.showingSolution {
                gaveUpOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { exitGame() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.06)))
                }
            }
        }
        .alert("Give Up?", isPresented: $showGiveUpAlert) {
            Button("Give Up", role: .destructive) {
                viewModel.giveUp()
                // Save with actual partial progress
                let result = viewModel.buildGameResult()
                modelContext.insert(result)
                if let lvl = viewModel.activeLevelId {
                    PersistenceManager.markLevelPlayed(
                        gameType: .shift, levelId: lvl, won: false,
                        score: viewModel.currentScore,
                        guessesUsed: viewModel.moveCount, context: modelContext
                    )
                }
            }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text("You can view the solution after giving up.")
        }
        .onChange(of: viewModel.moveCount) { _, _ in
            moveCountBounce = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                moveCountBounce = false
            }
        }
        .showTutorialOnFirstPlay(for: .shift)
    }

    // MARK: - Header

    private var gameHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SHIFT")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.65, green: 0.24, blue: 0.85),
                                     Color(red: 0.4, green: 0.6, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text(viewModel.isDaily ? "Daily Puzzle" : "Level \(viewModel.activeLevelId ?? 0)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            if viewModel.showingSolution {
                Text("SOLUTION")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(.orange.opacity(0.15)))
            } else {
                HStack(spacing: 8) {
                    pill(icon: "arrow.left.arrow.right", value: "\(viewModel.moveCount)")
                        .scaleEffect(moveCountBounce ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.4), value: moveCountBounce)
                    pill(icon: "clock", value: viewModel.timerString)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func pill(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(value).font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.06)))
    }

    // MARK: - Solution Grid (read-only)

    @ViewBuilder
    private func solutionGridSection(_ solGrid: ShiftGrid) -> some View {
        VStack(spacing: 8) {
            let solHighlighted: Set<Int> = {
                var cells = Set<Int>()
                for tw in viewModel.puzzle.targetWords {
                    if let loc = solGrid.findWord(tw.word) {
                        for c in loc.cells { cells.insert(c.row * ShiftGrid.size + c.col) }
                    }
                }
                return cells
            }()

            ShiftGridView(
                grid: .constant(solGrid),
                highlightedCells: solHighlighted,
                hintCells: [],
                interactive: false,
                onMove: { _ in }
            )
            .padding(.horizontal, 8)

            Button {
                viewModel.hideSolution()
            } label: {
                Label("Back to Your Board", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.08)))
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 14) {
            ctrlBtn(icon: "arrow.uturn.backward", label: "Undo", off: !viewModel.canUndo) {
                viewModel.undo()
            }
            ctrlBtn(icon: "arrow.uturn.forward", label: "Redo", off: !viewModel.canRedo) {
                viewModel.redo()
            }

            Spacer()

            if viewModel.gameState == .inProgress {
                ctrlBtn(icon: "flag.fill", label: "Give Up", off: false, tint: .red.opacity(0.7)) {
                    showGiveUpAlert = true
                }
            } else if viewModel.gameState == .gaveUp {
                ctrlBtn(icon: "eye.fill", label: "Solution",
                        off: viewModel.solutionGrid == nil, tint: .orange) {
                    viewModel.showSolution()
                }
            }

            ctrlBtn(icon: "arrow.counterclockwise", label: "Reset", off: false, tint: .white.opacity(0.5)) {
                viewModel.reset()
            }
        }
    }

    private func ctrlBtn(icon: String, label: String, off: Bool, tint: Color = .white,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 16, weight: .medium))
                Text(label).font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(off ? .white.opacity(0.2) : tint.opacity(0.8))
            .frame(width: 52, height: 44)
        }
        .disabled(off)
    }

    // MARK: - Gave Up Overlay

    private var gaveUpOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red.opacity(0.7))

                Text("GAVE UP")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    statRow("Moves Made", "\(viewModel.moveCount)", nil)
                    statRow("Words Found", "\(viewModel.completedWords.count)/\(viewModel.puzzle.targetWords.count)", nil)
                    statRow("Time", viewModel.timerString, nil)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

                HStack(spacing: 12) {
                    if viewModel.solutionGrid != nil {
                        Button { viewModel.showSolution() } label: {
                            Label("View Solution", systemImage: "eye")
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.orange)
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .background(Capsule().fill(.orange.opacity(0.15)))
                        }
                    }

                    Button { viewModel.reset() } label: {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(Capsule().fill(.white.opacity(0.1)))
                    }

                    Button { saveAndDismiss() } label: {
                        Text("Exit")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.65, green: 0.24, blue: 0.85),
                                                 Color(red: 0.4, green: 0.6, blue: 1.0)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                            )
                    }
                }
            }
            .padding(28)
        }
        .transition(.opacity)
    }

    // MARK: - Completion Overlay

    private func completionOverlay(score: Int) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 20) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: "star.fill").font(.system(size: 30)).foregroundStyle(.yellow)
                    }
                }
                Text("PUZZLE COMPLETE")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    statRow("Moves", "\(viewModel.moveCount)", nil)
                    statRow("Time", viewModel.timerString, nil)
                    statRow("Words Found", "\(viewModel.completedWords.count)/\(viewModel.puzzle.targetWords.count)", nil)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

                HStack(spacing: 12) {
                    ShareLink(item: viewModel.generateShareString()) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(Capsule().fill(.white.opacity(0.1)))
                    }
                    Button { saveAndDismiss() } label: {
                        Text("Continue")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 24).padding(.vertical, 10)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.65, green: 0.24, blue: 0.85),
                                                 Color(red: 0.4, green: 0.6, blue: 1.0)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                            )
                    }
                }
            }
            .padding(28)
        }
    }

    private func statRow(_ label: String, _ value: String, _ detail: String?) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            if let d = detail { Text(d).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4)) }
        }
    }

    // MARK: - Exit (preserves current state, no auto-loss)

    private func exitGame() {
        let result = viewModel.buildGameResult()
        modelContext.insert(result)
        // Don't mark level as played/lost — just save the game result
        dismiss()
    }

    // MARK: - Save & Dismiss (after completion or give-up)

    private func saveAndDismiss() {
        let result = viewModel.buildGameResult()
        modelContext.insert(result)
        if let lvl = viewModel.activeLevelId {
            let won: Bool
            if case .completed = viewModel.gameState { won = true } else { won = false }
            let sc: Int
            if case .completed(let s) = viewModel.gameState { sc = s } else { sc = 0 }
            PersistenceManager.markLevelPlayed(gameType: .shift, levelId: lvl, won: won, score: sc,
                                                guessesUsed: viewModel.moveCount, context: modelContext)
        }
        // Record daily streak
        if viewModel.isDaily, case .completed = viewModel.gameState {
            _ = StreakManager.recordDailyWin(game: "shift")
        }
        dismiss()
    }
}
