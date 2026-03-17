//
//  CargoGameView.swift
//  Prisma
//
//  Main container for a Cargo game session.
//  Header: CARGO label + timer pill + progress indicator.
//  Center: interactive grid.
//  Bottom: piece tray with rotate/flip controls.
//  Result overlay: shown inline when game ends.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CargoGameView: View {
    @State private var viewModel: CargoGameViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(viewModel: CargoGameViewModel = CargoGameViewModel(date: .now)) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Background
            AppTheme.appBackground()

            VStack(spacing: 0) {
                header
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                // Grid
                // Grid or Solution
                if viewModel.showingSolution {
                    // Show the perfect solution grid
                    solutionGrid
                        .padding(.horizontal, 20)
                        .frame(maxHeight: .infinity)
                } else {
                    CargoGridView(
                        grid: viewModel.grid,
                        ghostCells: viewModel.ghostCells,
                        ghostIsValid: viewModel.ghostIsValid,
                        pendingCells: viewModel.isAwaitingSubmit ? viewModel.ghostCells : [],
                        pendingPieceId: viewModel.pendingPieceId,
                        onDragPending: nil,
                        onHoverGrid: { viewModel.updateDragLocation(coord: $0) },
                        onDropGrid: {
                            viewModel.dropDraggingPiece()
                            Haptics.playMediumImpact()
                        }
                    )
                    .padding(.horizontal, 20)
                    .frame(maxHeight: .infinity)
                }

                // Result overlay or piece tray
                if viewModel.isGameOver {
                    resultOverlay
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    bottomControls
                        .padding(.bottom, 16)
                }
            }
        }
        .animation(.default, value: viewModel.showingSolution)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .showTutorialOnFirstPlay(for: .cargo)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("cancelDragSafe"))) { _ in
            viewModel.cancelDrag()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            ZStack {
                Text("CARGO")
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
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.8))
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
                            .foregroundStyle(.primary.opacity(0.4))
                            .padding(8)
                    }
                    .padding(.trailing, 12)
                }
            }

            HStack(spacing: 12) {
                // Timer pill
                CargoHeaderTimerView(viewModel: viewModel)

                // Progress pill
                progressPill
            }
            .padding(.top, 2)

            // Undo info
            if !viewModel.isGameOver {
                Text("Undos left: \(CargoGameViewModel.maxUndos - viewModel.undoCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.3))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }



    @ViewBuilder
    private var progressPill: some View {
        let pct = Int(viewModel.fillPercentage * 100)
        let label = Text("\(viewModel.pieces.count - viewModel.piecesRemaining)/\(viewModel.pieces.count) pieces · \(pct)%")
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

        if #available(iOS 26, *) {
            label.glassEffect(.regular, in: Capsule())
        } else {
            label.background(Capsule().fill(AppTheme.pillFill))
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 4) {
            if viewModel.isAwaitingSubmit {
                // Pending Placement Action Bar
                pendingActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Fixed height container for Rotate/Flip buttons to prevent squeezing
                ZStack {
                    if viewModel.selectedPieceIndex != nil && !viewModel.isGameOver {
                        HStack(spacing: 12) {
                            transformButton(icon: "rotate.right", action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.rotateSelectedPiece()
                                }
                                Haptics.playMediumImpact()
                            })
                            transformButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.flipSelectedPiece()
                                }
                                Haptics.playMediumImpact()
                            })
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(height: 44)

                // Piece tray
                CargoPieceTray(
                    pieces: viewModel.pieces,
                    placedPieceIds: viewModel.placedPieceIds,
                    selectedIndex: viewModel.selectedPieceIndex,
                    draggingId: viewModel.draggingPieceId,
                    pendingId: viewModel.pendingPieceId,
                    onDragStart: { viewModel.beginDrag(pieceId: $0) },
                    onDragCancel: { viewModel.cancelDrag() },
                    onSelect: { viewModel.selectPiece(at: $0) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                // Undo + Give Up row
                HStack(spacing: 12) {
                    // Undo button
                    Button {
                        viewModel.undoLastPlacement()
                        Haptics.playMediumImpact()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.canUndo ? .white : .primary.opacity(0.3))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(Color.primary.opacity(viewModel.canUndo ? 0.12 : 0.05))
                        )
                    }
                    .disabled(!viewModel.canUndo)

                    Spacer()

                    // Give Up / Done
                    Button {
                        viewModel.submitResult()
                        saveResult()
                        Haptics.playMediumImpact()
                    } label: {
                        Text(viewModel.piecesRemaining == 0 ? "Submit" : "Give Up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.7))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isAwaitingSubmit)
    }

    private var pendingActionBar: some View {
        HStack(spacing: 12) {
            // Remove
            Button {
                viewModel.cancelPendingPiece()
                Haptics.playMediumImpact()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.red.opacity(0.15)))
            }

            Spacer()

            // Rotate
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.rotatePendingPiece()
                }
                Haptics.playMediumImpact()
            } label: {
                Image(systemName: "rotate.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.primary.opacity(0.12)))
            }

            // Flip
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.flipPendingPiece()
                }
                Haptics.playMediumImpact()
            } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.primary.opacity(0.12)))
            }

            Spacer()

            // Submit
            Button {
                viewModel.submitPendingPiece()
                Haptics.playMediumImpact()
                if viewModel.isGameOver { saveResult() }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(viewModel.ghostIsValid ? Color.green : Color.primary.opacity(0.3))
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(viewModel.ghostIsValid ? Color.green.opacity(0.25) : Color.primary.opacity(0.1)))
            }
            .disabled(!viewModel.ghostIsValid)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Result Overlay

    private var resultOverlay: some View {
        guard case .completed(let score, let isPerfect) = viewModel.gameState else {
            return AnyView(EmptyView())
        }

        let title = isPerfect ? "Perfect Clear! ⭐" : score >= 700 ? "Well Packed! 📦" : "Partial Fill"
        let pct = Int(viewModel.fillPercentage * 100)

        return AnyView(
            ResultOverlayTemplate(
                style: .panel,
                header: .custom(title: title, subtitle: nil),
                stats: [
                    ResultStat(label: "Filled", value: "\(pct)%"),
                    ResultStat(label: "Score", value: "\(score)"),
                    ResultStat(label: "Time", value: viewModel.timerString)
                ]
            ) {
                EmptyView()
            } actions: {
                VStack(spacing: 12) {
                    if !viewModel.isDaily {
                        localResultActions
                    } else {
                        ResultShareButton(shareString: viewModel.generateShareString())
                        ResultPrimaryButton(title: "Done") { dismiss() }
                    }

                    if !viewModel.showingSolution {
                        Button {
                            viewModel.showSolution()
                            Haptics.playMediumImpact()
                        } label: {
                            Text("Show Solution")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.6))
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .onAppear {
                if viewModel.isDaily { saveResult() }
            }
        )
    }

    private func transformButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.primary.opacity(0.12)))
        }
    }

    // MARK: - Solution Grid

    private var solutionGrid: some View {
        var tempGrid = CargoGrid(rows: viewModel.grid.rows, cols: viewModel.grid.cols, blockedCells: viewModel.puzzle.blockedCells)
        tempGrid.populateSolutionMode(with: viewModel.puzzle.pieces)
        
        // Render it
        return CargoGridView(
            grid: tempGrid,
            ghostCells: [],
            ghostIsValid: false,
            pendingCells: [],
            pendingPieceId: nil,
            onHoverGrid: { _ in },
            onDropGrid: {}
        )
        // Note: we'll overlay the actual solution colors manually or just use the grid.
    }

    private var localResultActions: some View {
        HStack(spacing: 12) {
            ShareLink(item: viewModel.generateShareString()) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.7))
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.08)))
            }

            ResultPrimaryButton(title: "Done") { dismiss() }

            if let levelId = viewModel.activeLevelId, levelId < 100 {
                ResultPrimaryButton(title: "Next Level →") {
                    viewModel.loadLevel(levelId + 1)
                    saveResult()
                }
            }
        }
    }

    // MARK: - Persistence

    private func saveResult() {
        guard case .completed(let score, _) = viewModel.gameState else { return }

        if let levelId = viewModel.activeLevelId {
            PersistenceManager.markLevelPlayed(
                gameType: .cargo,
                levelId: levelId,
                won: score >= 700,
                score: score,
                guessesUsed: 0,
                durationSeconds: Double(viewModel.elapsedSeconds),
                context: modelContext
            )
            // Also save GameResult for local mode to enable history display with user state
            let result = viewModel.buildLocalGameResult()
            PersistenceManager.save(result, context: modelContext)
        }
        if viewModel.isDaily {
            let gameDate = Calendar.current.startOfDay(for: Date())
            if PersistenceManager.fetchDailyResult(for: .cargo, on: gameDate, context: modelContext) == nil {
                let result = viewModel.buildGameResult(gameDate: gameDate)
                PersistenceManager.save(result, context: modelContext)
            }
            // Record daily streak
            if score >= 700 {
                _ = StreakManager.recordDailyWin(game: "cargo")
            }
        }
    }
}

// MARK: - Isolated Timer View (Prevents whole screen redraws)

struct CargoHeaderTimerView: View {
    let viewModel: CargoGameViewModel

    var body: some View {
        let label = Text("⏱ \(viewModel.timerString)")
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

        if #available(iOS 26, *) {
            label.glassEffect(.regular, in: Capsule())
        } else {
            label.background(Capsule().fill(AppTheme.pillFill))
        }
    }
}

// MARK: - Previews

#Preview("Daily — In Progress") {
    CargoGameView()
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}

#Preview("Local Level 1") {
    CargoGameView(viewModel: CargoGameViewModel(level: 1))
        .modelContainer(for: [LevelProgress.self, GameResult.self], inMemory: true)
}
