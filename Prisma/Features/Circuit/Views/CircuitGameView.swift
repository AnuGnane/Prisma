//
//  CircuitGameView.swift
//  Prisma
//
//  Full-screen Circuit game view.
//  Header matches the unified Signals/Cargo/Shift pattern:
//  game name centred with gradient, back button left, level + ? right,
//  timer pill + game controls sub-row.
//  Result and gave-up overlays use ResultOverlayTemplate for consistency.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct CircuitGameView: View {
    @State private var viewModel: CircuitGameViewModel
    @State private var hasSavedResult = false
    @State private var showingTutorial = false
    @State private var showGiveUpAlert = false
    @State private var hasTriggeredWinFX = false
    @State private var winPulse: Double = 0   // 0 → 1 → 0 brief flare on win
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(levelId: Int) {
        _viewModel = State(initialValue: CircuitGameViewModel(levelId: levelId))
    }

    init(viewModel: CircuitGameViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppTheme.appBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Unified game header
                CircuitGameHeader(
                    viewModel: viewModel,
                    onBack: { dismiss() },
                    onShowTutorial: { showingTutorial = true },
                    onUndo: { viewModel.undoToLastBranch() },
                    onReset: { viewModel.reset() },
                    onGiveUp: { showGiveUpAlert = true },
                    onViewSolution: { viewModel.showSolution() }
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Grid — solution or interactive
                if viewModel.showingSolution {
                    CircuitSolutionGridView(viewModel: viewModel)
                        .padding(.horizontal, 16)
                } else {
                    CircuitGridView(viewModel: viewModel)
                        .padding(.horizontal, 16)
                }

                // Dashboard panel — path status + star coverage bar
                CircuitDashboardPanel(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // "Finish Early" button — visible when all terminals are
                // powered but the board isn't fully covered. Gives 1–2 stars
                // but does NOT submit to the daily leaderboard.
                if viewModel.canFinishEarly {
                    Button {
                        viewModel.forceFinish()
                    } label: {
                        Label("Finish Early", systemImage: "checkmark.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [AppTheme.circuit, AppTheme.circuit.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            )
                    }
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .animation(.easeInOut(duration: 0.25), value: viewModel.canFinishEarly)
                }

                Spacer(minLength: 0)
            }

            // Victory flare — overlays a brief white flash synced with haptic
            if winPulse > 0 {
                Color.white
                    .ignoresSafeArea()
                    .opacity(winPulse * 0.18)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }

            // Completion overlay
            if case .completed(let stars) = viewModel.gameState {
                CircuitResultView(
                    viewModel: viewModel,
                    stars: stars,
                    onDone: { dismiss() },
                    onNextLevel: nextLevelAction.map { advance in { advance() } }
                )
                .onAppear {
                    saveCompletionIfNeeded()
                    triggerWinFeedbackIfNeeded(stars: stars)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.gameState == .inProgress)
            }

            // Gave up overlay
            if viewModel.gameState == .gaveUp && !viewModel.showingSolution {
                CircuitGaveUpOverlay(viewModel: viewModel, saveAndDismiss: {
                    saveGiveUpIfNeeded()
                    dismiss()
                })
                .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingTutorial) {
            CircuitTutorialView()
        }
        .alert("Give Up?", isPresented: $showGiveUpAlert) {
            Button("Give Up", role: .destructive) {
                viewModel.giveUp()
            }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text("You can view the solution after giving up.")
        }
    }

    // MARK: - Helpers

    private var nextLevelAction: (() -> Void)? {
        guard let currentId = viewModel.activeLevelId else { return nil }
        let nextId = currentId + 1
        guard CircuitLevelLoader.level(for: nextId) != nil else { return nil }
        return {
            hasSavedResult = false
            hasTriggeredWinFX = false
            winPulse = 0
            viewModel = CircuitGameViewModel(levelId: nextId)
        }
    }

    /// Plays a one-shot haptic + white flare when the level transitions to completed.
    private func triggerWinFeedbackIfNeeded(stars: Int) {
        guard !hasTriggeredWinFX else { return }
        hasTriggeredWinFX = true

        #if canImport(UIKit)
        if stars >= 2 {
            let notif = UINotificationFeedbackGenerator()
            notif.prepare()
            notif.notificationOccurred(.success)
        }
        let impact = UIImpactFeedbackGenerator(style: stars >= 3 ? .heavy : .medium)
        impact.prepare()
        impact.impactOccurred()
        #endif

        withAnimation(.easeOut(duration: 0.12)) { winPulse = 1.0 }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeInOut(duration: 0.55)) { winPulse = 0.0 }
        }
    }

    private func saveCompletionIfNeeded() {
        guard !hasSavedResult else { return }
        guard case .completed = viewModel.gameState else { return }

        let result = viewModel.buildGameResult()
        // ScoreManager handles persistence dedup internally.
        // GameCenterManager.claimDailyGCSubmission guards against duplicate GC calls.
        ScoreManager.shared.processAndSaveResult(result, context: modelContext)
        hasSavedResult = true
    }

    private func saveGiveUpIfNeeded() {
        guard !hasSavedResult else { return }

        let result = viewModel.buildGameResult()
        ScoreManager.shared.processAndSaveResult(result, context: modelContext)
        hasSavedResult = true
    }
}

// MARK: - Unified Game Header

/// Custom header that matches the Signals / Cargo / Shift pattern:
/// game name centred with brand gradient, back button left, level + ? right,
/// timer pill + action controls in a sub-row.
private struct CircuitGameHeader: View {
    let viewModel: CircuitGameViewModel
    let onBack: () -> Void
    let onShowTutorial: () -> Void
    let onUndo: () -> Void
    let onReset: () -> Void
    let onGiveUp: () -> Void
    let onViewSolution: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            // ── Title row ──────────────────────────────────────────────────
            ZStack {
                // Centred game name with brand gradient
                Text(viewModel.isDaily ? "CIRCUIT · DAILY" : "CIRCUIT")
                    .font(.system(size: viewModel.isDaily ? 18 : 22, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.circuit, AppTheme.cascadeBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                HStack {
                    // Back / exit button
                    Button {
                        onBack()
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

                    // Level label + How to Play
                    HStack(spacing: 4) {
                        if let id = viewModel.activeLevelId {
                            Text("L\(id)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            onShowTutorial()
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(minHeight: 44)
                        }
                    }
                    .padding(.trailing, 8)
                }
            }

            // ── Controls sub-row ───────────────────────────────────────────
            if viewModel.showingSolution {
                // Solution banner replaces the controls row
                Text("SOLUTION")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(.orange.opacity(0.15)))
            } else {
                HStack(spacing: 8) {
                    // Timer pill
                    timerPill

                    Spacer()

                    if viewModel.gameState == .inProgress {
                        // Undo
                        Button("Undo", systemImage: "arrow.uturn.backward") {
                            onUndo()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.circuit)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.circuit.opacity(0.1)))
                        .labelStyle(.iconOnly)

                        // Reset
                        Button("Reset", systemImage: "arrow.counterclockwise") {
                            onReset()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.primary.opacity(0.07)))
                        .labelStyle(.iconOnly)

                        // Give Up
                        Button {
                            onGiveUp()
                        } label: {
                            Label("Give Up", systemImage: "flag.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .frame(minHeight: 44)
                        }
                    }

                    if viewModel.gameState == .gaveUp {
                        Button {
                            onViewSolution()
                        } label: {
                            Label("Solution", systemImage: "eye.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .frame(minHeight: 44)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var timerPill: some View {
        let label = HStack(spacing: 4) {
            Image(systemName: "clock").font(.system(size: 10, weight: .bold))
            Text(viewModel.timerString).font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(.primary.opacity(0.7))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)

        return Group {
            if #available(iOS 26, *) {
                label.glassEffect(.regular, in: Capsule())
            } else {
                label.background(Capsule().fill(AppTheme.pillFill))
            }
        }
    }
}

// MARK: - Solution Grid (read-only replay)

private struct CircuitSolutionGridView: View {
    let viewModel: CircuitGameViewModel

    @State private var solutionVM: CircuitGameViewModel?

    var body: some View {
        VStack(spacing: 12) {
            if let vm = solutionVM {
                CircuitGridView(viewModel: vm, allowsDrawing: false)
            } else {
                AppEmptyState(
                    systemImage: "xmark.circle",
                    title: "No solution available",
                    message: "We couldn't load a solution for this board."
                )
            }

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
        .onAppear { loadSolution() }
    }

    private func loadSolution() {
        let solutionJSON: String?
        if let id = viewModel.activeLevelId {
            solutionJSON = CircuitLevelLoader.level(for: id)?.solutionStateJSON
        } else {
            solutionJSON = CircuitLevelLoader.dailyLevel(for: .now).solutionStateJSON
        }

        guard let json = solutionJSON,
              let state = CircuitStateSerializer.deserialize(json) else { return }

        let vm: CircuitGameViewModel
        if let id = viewModel.activeLevelId {
            vm = CircuitGameViewModel(levelId: id)
        } else {
            vm = CircuitGameViewModel(date: .now)
        }
        vm.restoreState(from: state)
        solutionVM = vm
    }
}

// MARK: - Dashboard Panel

/// Fills the space below the grid with live path-status indicators and
/// a star-threshold coverage bar. Visible during active play and solution view.
private struct CircuitDashboardPanel: View {
    let viewModel: CircuitGameViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            pathStatusRow
            coverageBar
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primary.opacity(0.05))
        )
    }

    // MARK: Path Status Row

    private var pathStatusRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PATHS")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.secondary)
                .kerning(1.2)

            let pairs = viewModel.level.terminalPairs
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(pairs.count, 4))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(pairs.indices, id: \.self) { i in
                    pathPill(for: pairs[i])
                }
            }
        }
    }

    private func pathPill(for pair: TerminalPair) -> some View {
        let color = pair.color.swiftUIColor
        let isComplete = viewModel.activePaths[pair.color]?.isComplete == true
        let hasPath = viewModel.activePaths[pair.color] != nil

        return HStack(spacing: 5) {
            Circle()
                .fill(isComplete ? color : (hasPath ? color.opacity(0.5) : Color.primary.opacity(0.15)))
                .frame(width: 8, height: 8)
                .overlay(
                    isComplete
                        ? Circle().strokeBorder(color.opacity(0.4), lineWidth: 1)
                        : nil
                )

            Image(systemName: isComplete ? "checkmark" : (hasPath ? "arrow.right" : "minus"))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isComplete ? color : .secondary.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isComplete ? color.opacity(0.12) : Color.primary.opacity(0.06))
                .overlay(
                    isComplete
                        ? RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.25), lineWidth: 1)
                        : nil
                )
        )
    }

    // MARK: Coverage Bar

    private var coverageBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("COVERAGE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .kerning(1.2)
                Spacer()
                Text("\(Int(viewModel.coveragePercent * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(coverageColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.circuit.opacity(0.7), coverageColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * viewModel.coveragePercent, height: 8)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.coveragePercent)

                    // 80% threshold marker (2★)
                    thresholdMarker(at: 0.80, width: geo.size.width, label: "2★")

                    // 100% threshold marker (3★)
                    thresholdMarker(at: 1.00, width: geo.size.width, label: "3★")
                }
            }
            .frame(height: 22)
        }
    }

    private func thresholdMarker(at fraction: CGFloat, width: CGFloat, label: String) -> some View {
        let xPos = width * fraction
        let reached = viewModel.coveragePercent >= fraction

        return VStack(spacing: 0) {
            Rectangle()
                .fill(reached ? Color.white.opacity(0.8) : Color.primary.opacity(0.25))
                .frame(width: 1.5, height: 8)

            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(reached ? coverageColor : .secondary.opacity(0.5))
                .offset(x: fraction == 1.00 ? -10 : -6)
                .padding(.top, 2)
        }
        .offset(x: xPos - 0.75)
    }

    private var coverageColor: Color {
        let pct = viewModel.coveragePercent
        if pct >= 1.0  { return .yellow }
        if pct >= 0.80 { return AppTheme.circuit }
        return .secondary
    }
}

// MARK: - Gave Up Overlay

private struct CircuitGaveUpOverlay: View {
    let viewModel: CircuitGameViewModel
    let saveAndDismiss: () -> Void

    var body: some View {
        ResultOverlayTemplate(
            style: .fullScreen,
            header: .iconTitle(
                icon: "flag.fill",
                color: .red.opacity(0.8),
                title: "GAVE UP"
            ),
            stats: [
                ResultStat(label: "Terminals Powered", value: "\(viewModel.poweredTerminalCount)/\(viewModel.level.terminalPairs.count)"),
                ResultStat(label: "Time", value: viewModel.timerString),
                ResultStat(label: "Coverage", value: "\(Int(viewModel.coveragePercent * 100))%")
            ],
            accentColor: AppTheme.circuit
        ) {
            EmptyView()
        } actions: {
            VStack(spacing: 12) {
                ResultPrimaryButton(title: "View Solution", accentColor: AppTheme.circuit) {
                    viewModel.showSolution()
                }
                ResultSecondaryButton(title: "Exit") {
                    saveAndDismiss()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CircuitGameView(levelId: 1)
    }
}
