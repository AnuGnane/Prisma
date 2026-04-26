//
//  ShiftGameView.swift
//  Prisma
//
//  Main game view for Shift v3 — clean, no par/hints.
//

import SwiftUI
import SwiftData

@MainActor
struct ShiftGameView: View {
    @State private var viewModel: ShiftGameViewModel
    @State private var showGiveUpAlert = false
    @State private var moveCountBounce = false
    @State private var showHowToPlay = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            AppTheme.appBackground()

            VStack(spacing: 0) {
                ShiftGameHeader(
                    viewModel: viewModel,
                    moveCountBounce: moveCountBounce,
                    reduceMotion: reduceMotion,
                    exitGame: exitGame,
                    showGiveUpAlert: { showGiveUpAlert = true },
                    showHowToPlay: { showHowToPlay = true }
                )
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
                    ShiftSolutionGridSection(viewModel: viewModel, solGrid: solGrid)
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

                ShiftControls(viewModel: viewModel, showGiveUpAlert: $showGiveUpAlert)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            // Completion overlay
            if case .completed(let score) = viewModel.gameState {
                ShiftCompletionOverlay(viewModel: viewModel, score: score, saveAndDismiss: saveAndDismiss)
            }

            // Gave up overlay
            if viewModel.gameState == .gaveUp && !viewModel.showingSolution {
                ShiftGaveUpOverlay(viewModel: viewModel, saveAndDismiss: saveAndDismiss)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .alert("Give Up?", isPresented: $showGiveUpAlert) {
            Button("Give Up", role: .destructive) {
                viewModel.giveUp()
            }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text("You can view the solution after giving up.")
        }
        .onChange(of: viewModel.moveCount) { _, _ in
            guard !reduceMotion else {
                moveCountBounce = false
                return
            }
            moveCountBounce = true
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                moveCountBounce = false
            }
        }
        .showTutorialOnFirstPlay(for: .shift)
        .sheet(isPresented: $showHowToPlay) {
            HowToPlaySheet(gameType: .shift)
        }
    }

    // MARK: - Exit (mid-game — no save for daily to avoid blocking replay)

    private func exitGame() {
        if !viewModel.isDaily {
            let result = viewModel.buildGameResult()
            modelContext.insert(result)
        }
        dismiss()
    }

    // MARK: - Save & Dismiss (after completion or give-up)

    private func saveAndDismiss() {
        let result = viewModel.buildGameResult()

        // Route through centralised ScoreManager — handles daily dedup,
        // level progression, GC score submission, streak tracking,
        // and all achievement reporting in one place.
        ScoreManager.shared.processAndSaveResult(result, context: modelContext)

        dismiss()
    }
}

// MARK: - Subviews

struct ShiftGameHeader: View {
    let viewModel: ShiftGameViewModel
    let moveCountBounce: Bool
    let reduceMotion: Bool
    let exitGame: () -> Void
    let showGiveUpAlert: () -> Void
    let showHowToPlay: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Text("SHIFT")
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
                        exitGame()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(minHeight: 44)
                    }
                    .padding(.leading, 8)

                    Spacer()

                    if viewModel.gameState == .inProgress {
                        HStack(spacing: 8) {
                            Button {
                                showHowToPlay()
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(minHeight: 44)
                            }
                            
                            Button {
                                showGiveUpAlert()
                            } label: {
                                Label("Give Up", systemImage: "flag.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.red.opacity(0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(minHeight: 44)
                            }
                        }
                        .padding(.trailing, 12)
                    }
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
                    ShiftPill(icon: "arrow.left.arrow.right", value: "\(viewModel.moveCount)")
                        .scaleEffect(moveCountBounce ? 1.15 : 1.0)
                        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.4), value: moveCountBounce)
                    if AppSettings.showGameTimer {
                        ShiftPill(icon: "clock", value: viewModel.timerString)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShiftPill: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(value).font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(.primary.opacity(0.7))
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Capsule().fill(AppTheme.pillFill))
    }
}

struct ShiftSolutionGridSection: View {
    let viewModel: ShiftGameViewModel
    let solGrid: ShiftGrid

    var body: some View {
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
                    .foregroundStyle(.primary.opacity(0.7))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(.primary.opacity(0.08)))
            }
        }
    }
}

struct ShiftControls: View {
    let viewModel: ShiftGameViewModel
    @Binding var showGiveUpAlert: Bool

    var body: some View {
        HStack(spacing: 14) {
            ShiftCtrlBtn(icon: "arrow.uturn.backward", label: "Undo", off: !viewModel.canUndo) {
                viewModel.undo()
            }
            ShiftCtrlBtn(icon: "arrow.uturn.forward", label: "Redo", off: !viewModel.canRedo) {
                viewModel.redo()
            }

            Spacer()

            if viewModel.gameState == .gaveUp {
                ShiftCtrlBtn(icon: "eye.fill", label: "Solution",
                        off: viewModel.solutionGrid == nil, tint: .orange) {
                    viewModel.showSolution()
                }
            }
        }
    }
}

struct ShiftCtrlBtn: View {
    let icon: String
    let label: String
    let off: Bool
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 16, weight: .medium))
                Text(label).font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(off ? .primary.opacity(0.2) : tint.opacity(0.8))
            .frame(width: 52, height: 44)
        }
        .disabled(off)
    }
}

struct ShiftGaveUpOverlay: View {
    let viewModel: ShiftGameViewModel
    let saveAndDismiss: () -> Void

    var body: some View {
        ResultOverlayTemplate(
            style: .fullScreen,
            header: .titleSubtitle(
                title: "GAVE UP",
                subtitle: "\(viewModel.completedWords.count) of \(viewModel.puzzle.targetWords.count) words found"
            ),
            stats: [
                ResultStat(label: "Moves Made", value: "\(viewModel.moveCount)"),
                ResultStat(label: "Time", value: viewModel.timerString)
            ],
            accentColor: AppTheme.shift
        ) {
            EmptyView()
        } actions: {
            VStack(spacing: 10) {
                if viewModel.solutionGrid != nil {
                    ResultPrimaryButton(title: "View Solution", accentColor: AppTheme.shift) {
                        viewModel.showSolution()
                    }
                }
                ResultSecondaryButton(title: "Exit") {
                    saveAndDismiss()
                }
            }
        }
    }
}

struct ShiftCompletionOverlay: View {
    let viewModel: ShiftGameViewModel
    let score: Int
    let saveAndDismiss: () -> Void

    var body: some View {
        ResultOverlayTemplate(
            style: .fullScreen,
            header: .stars(title: "PUZZLE COMPLETE"),
            stats: [
                ResultStat(label: "Moves", value: "\(viewModel.moveCount)"),
                ResultStat(label: "Time", value: viewModel.timerString),
                ResultStat(label: "Words Found", value: "\(viewModel.completedWords.count)/\(viewModel.puzzle.targetWords.count)")
            ],
            accentColor: AppTheme.shift
        ) {
            EmptyView()
        } actions: {
            HStack(spacing: 12) {
                ShareLink(item: viewModel.generateShareString()) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Capsule().fill(.primary.opacity(0.1)))
                }
                Button { saveAndDismiss() } label: {
                    Text("Continue")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.primary)
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [AppTheme.shift, AppTheme.cascadeBlue],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                        )
                }
            }
        }
    }
}
