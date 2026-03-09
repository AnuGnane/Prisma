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

    init(puzzle: ShiftPuzzle, restoredGrid: ShiftGrid, isDaily: Bool, levelId: Int? = nil) {
        _viewModel = State(initialValue: ShiftGameViewModel(
            puzzle: puzzle, restoredGrid: restoredGrid, isDaily: isDaily, levelId: levelId
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
                .fixedSize(horizontal: false, vertical: true)
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
        .toolbar(.hidden, for: .navigationBar)
        .alert("Give Up?", isPresented: $showGiveUpAlert) {
            Button("Give Up", role: .destructive) {
                viewModel.giveUp()
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
        VStack(spacing: 4) {
            ZStack {
                Text("SHIFT")
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
                        exitGame()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(8)
                    }
                    .padding(.leading, 8)

                    Spacer()

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
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
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
                Button {
                    showGiveUpAlert = true
                } label: {
                    Text("Give Up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            } else if viewModel.gameState == .gaveUp {
                ctrlBtn(icon: "eye.fill", label: "Solution",
                        off: viewModel.solutionGrid == nil, tint: .orange) {
                    viewModel.showSolution()
                }
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
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("GAVE UP")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("\(viewModel.completedWords.count) of \(viewModel.puzzle.targetWords.count) words found")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(spacing: 8) {
                    statRow("Moves Made", "\(viewModel.moveCount)", nil)
                    statRow("Time", viewModel.timerString, nil)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.12)))

                VStack(spacing: 10) {
                    if viewModel.solutionGrid != nil {
                        Button { viewModel.showSolution() } label: {
                            Text("View Solution")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
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
                        }
                    }

                    Button { saveAndDismiss() } label: {
                        Text("Exit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(32)
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
        // Always save state on exit, so mid-game progress is preserved
        let result = viewModel.buildGameResult()
        modelContext.insert(result)
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
