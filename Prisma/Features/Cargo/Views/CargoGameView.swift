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

@MainActor
struct CargoGameView: View {
    @State private var viewModel: CargoGameViewModel
    @State private var showHowToPlay = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: CargoGameViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    init() {
        _viewModel = State(initialValue: CargoGameViewModel(date: .now))
    }

    var body: some View {
        ZStack {
            // Background
            AppTheme.appBackground()

            VStack(spacing: 0) {
                CargoHeader(viewModel: viewModel, dismiss: dismiss, showHowToPlay: { showHowToPlay = true })
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                // Grid
                // Grid or Solution
                if viewModel.showingSolution {
                    // Show the perfect solution grid
                    CargoSolutionGrid(viewModel: viewModel)
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
                    CargoResultOverlay(viewModel: viewModel, dismiss: dismiss, saveResult: saveResult)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    CargoBottomControls(viewModel: viewModel, reduceMotion: reduceMotion, saveResult: saveResult)
                        .padding(.bottom, 16)
                }
            }
        }
        .animation(reduceMotion ? nil : .default, value: viewModel.showingSolution)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .showTutorialOnFirstPlay(for: .cargo)
        .sheet(isPresented: $showHowToPlay) {
            HowToPlaySheet(gameType: .cargo)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("cancelDragSafe"))) { _ in
            viewModel.cancelDrag()
        }
    }

    // MARK: - Persistence

    private func saveResult() {
        guard case .completed(let score, let isPerfect) = viewModel.gameState else { return }
        let isWin = score >= 700

        if let levelId = viewModel.activeLevelId {
            PersistenceManager.markLevelPlayed(
                gameType: .cargo,
                levelId: levelId,
                won: isWin,
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
            // Only save a daily result on a real win (≥70% fill).
            // Give-ups (score < 700) are intentionally not persisted so the player
            // can retry the same day's puzzle — shown as "unplayed" to friends.
            if isWin {
                let gameDate = Calendar.current.startOfDay(for: Date())
                if PersistenceManager.fetchDailyResult(for: .cargo, on: gameDate, context: modelContext) == nil {
                    let result = viewModel.buildGameResult(gameDate: gameDate)
                    PersistenceManager.save(result, context: modelContext)
                }
            }
        }

        // Game Center (runs for both local and daily; idempotent for same-day calls)
        reportToGameCenter(score: score, isPerfect: isPerfect)
    }
}

// MARK: - Game Center Reporting

extension CargoGameView {
    private func reportToGameCenter(score: Int, isPerfect: Bool) {
        let gc = GameCenterManager.shared
        let isWin = score >= 700

        // First-Cargo achievement fires on any win (GC deduplicates at 100%)
        if isWin {
            gc.reportAchievement(GameCenterManager.Achievement.firstCargo)
        }

        if viewModel.isDaily && isPerfect {
            // Daily best: only submit to the leaderboard on a perfect clear
            // (100% board fill). Incomplete solves save locally but stay off
            // the leaderboard to keep competition fair.
            gc.submitScore(viewModel.elapsedSeconds,
                           leaderboardIDs: [GameCenterManager.Leaderboard.cargoDailyBest])

            // Record the daily-win for the in-app streak counter. Streaks are
            // intentionally app-only — no Game Center leaderboard, no GC
            // achievements (Phase 4, 2026-04-25).
            _ = StreakManager.recordDailyWin(game: "cargo")

            // Perfect Cargo achievement
            gc.reportAchievement(GameCenterManager.Achievement.perfectCargo)
        }

        if !viewModel.isDaily && isWin {
            // Local Mastery leaderboard still updates — it's a real ranked
            // board across all players. Local mastery *achievements* removed
            // in Phase 4 (2026-04-25); milestones now live in
            // `Badge.local25 / 50 / 100`.
            let totalWon = PersistenceManager.totalLocalWins(context: modelContext)
            gc.submitScore(totalWon,
                           leaderboardIDs: [GameCenterManager.Leaderboard.localMastery])
        }

        // Invalidate friends summary cache so the local player's game icons
        // update promptly when switching to the Friends tab.
        FriendsService.shared.invalidateCache()
    }
}

// MARK: - Subviews

struct CargoHeader: View {
    let viewModel: CargoGameViewModel
    let dismiss: DismissAction
    let showHowToPlay: () -> Void

    var body: some View {
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
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(minHeight: 44)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                    
                    if !viewModel.isGameOver {
                        HStack(spacing: 8) {
                            Button {
                                showHowToPlay()
                                Haptics.playLightImpact()
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(minHeight: 44)
                            }

                            Button {
                                viewModel.reset()
                                Haptics.playMediumImpact()
                            } label: {
                                Label("Reset", systemImage: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(minHeight: 44)
                            }
                        }
                        .padding(.trailing, 12)
                    }
                }
            }

            HStack(spacing: 12) {
                // Timer pill
                if AppSettings.showGameTimer {
                    CargoHeaderTimerView(viewModel: viewModel)
                }

                // Progress pill
                CargoProgressPill(viewModel: viewModel)
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
}

struct CargoProgressPill: View {
    let viewModel: CargoGameViewModel

    var body: some View {
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
}

struct CargoBottomControls: View {
    let viewModel: CargoGameViewModel
    let reduceMotion: Bool
    let saveResult: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            if viewModel.isAwaitingSubmit {
                // Pending Placement Action Bar
                CargoPendingActionBar(viewModel: viewModel, reduceMotion: reduceMotion, saveResult: saveResult)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Fixed height container for Rotate/Flip buttons to prevent squeezing
                ZStack {
                    if viewModel.selectedPieceIndex != nil && !viewModel.isGameOver {
                        HStack(spacing: 12) {
                            transformButton(icon: "rotate.right") {
                                if reduceMotion {
                                    viewModel.rotateSelectedPiece()
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.rotateSelectedPiece()
                                    }
                                }
                                Haptics.playMediumImpact()
                            }
                            transformButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill") {
                                if reduceMotion {
                                    viewModel.flipSelectedPiece()
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.flipSelectedPiece()
                                    }
                                }
                                Haptics.playMediumImpact()
                            }
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
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isAwaitingSubmit)
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
}

struct CargoPendingActionBar: View {
    let viewModel: CargoGameViewModel
    let reduceMotion: Bool
    let saveResult: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Remove
            Button {
                viewModel.cancelPendingPiece()
                Haptics.playMediumImpact()
            } label: {
                CargoActionButton(icon: "xmark", text: "Remove", tint: .red)
            }

            Spacer()

            // Rotate
            Button {
                if reduceMotion {
                    viewModel.rotatePendingPiece()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.rotatePendingPiece()
                    }
                }
                Haptics.playMediumImpact()
            } label: {
                CargoActionButton(icon: "rotate.right", text: "Rotate", tint: .primary)
            }

            // Flip
            Button {
                if reduceMotion {
                    viewModel.flipPendingPiece()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.flipPendingPiece()
                    }
                }
                Haptics.playMediumImpact()
            } label: {
                CargoActionButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", text: "Flip", tint: .primary)
            }

            Spacer()

            // Submit
            Button {
                viewModel.submitPendingPiece()
                Haptics.playMediumImpact()
                if viewModel.isGameOver { saveResult() }
            } label: {
                CargoActionButton(icon: "checkmark", text: "Place",
                                  tint: viewModel.ghostIsValid ? .green : .primary.opacity(0.3))
            }
            .disabled(!viewModel.ghostIsValid)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

struct CargoResultOverlay: View {
    let viewModel: CargoGameViewModel
    let dismiss: DismissAction
    let saveResult: () -> Void

    var body: some View {
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
                ],
                accentColor: AppTheme.cargo
            ) {
                EmptyView()
            } actions: {
                VStack(spacing: 12) {
                    if !viewModel.isDaily {
                        CargoLocalResultActions(viewModel: viewModel, dismiss: dismiss, saveResult: saveResult)
                    } else {
                        ResultShareButton(shareString: viewModel.generateShareString(), accentColor: AppTheme.cargo)
                        ResultPrimaryButton(title: "Done", accentColor: AppTheme.cargo) { dismiss() }
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
}

struct CargoSolutionGrid: View {
    let viewModel: CargoGameViewModel

    var body: some View {
        // Render the canonical 100%-fill solution. `solutionCells` is populated
        // for every puzzle: the procedural generator sets them directly, and
        // JSON-loaded levels get them from the offline solver that runs in
        // `scratch/solve_cargo.py`. If any piece is missing a solution (e.g.
        // fallback puzzle, corrupt JSON), we fall back to the player's final
        // grid rather than painting everything at (0,0).
        let solutionGrid = viewModel.buildSolutionGrid() ?? viewModel.grid

        CargoGridView(
            grid: solutionGrid,
            ghostCells: [],
            ghostIsValid: false,
            pendingCells: [],
            pendingPieceId: nil,
            onHoverGrid: { _ in },
            onDropGrid: {}
        )
    }
}

struct CargoLocalResultActions: View {
    let viewModel: CargoGameViewModel
    let dismiss: DismissAction
    let saveResult: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ShareLink(item: viewModel.generateShareString()) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.7))
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.08)))
            }

            ResultPrimaryButton(title: "Done", accentColor: AppTheme.cargo) { dismiss() }

            if let levelId = viewModel.activeLevelId, levelId < GameType.cargo.localLevelCount {
                ResultPrimaryButton(title: "Next Level →", accentColor: AppTheme.cargo) {
                    viewModel.loadLevel(levelId + 1)
                    saveResult()
                }
            }
        }
    }
}

// MARK: - Cargo Action Button (icon + label, single-line safe)

private struct CargoActionButton: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .frame(width: 64, height: 52)
        .background(Capsule().fill(tint.opacity(text == "Remove" ? 0.12 : 0.10)))
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
