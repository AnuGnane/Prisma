//
//  CircuitGameView.swift
//  Prisma
//
//  Full-screen Circuit game view.
//  Hosts the toolbar (timer, undo, reset, give up), the CircuitGridView, and the
//  CircuitResultView overlay when the game is complete.
//

import SwiftUI
import SwiftData

struct CircuitGameView: View {
    @State private var viewModel: CircuitGameViewModel
    @State private var hasSavedResult = false
    @State private var showingTutorial = false
    @State private var showGiveUpAlert = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 0.0, green: 0.78, blue: 1.0)

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
                // Toolbar
                toolbar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // Grid — solution or interactive
                if viewModel.showingSolution {
                    CircuitSolutionGridView(viewModel: viewModel)
                        .padding(.horizontal, 16)
                } else {
                    CircuitGridView(viewModel: viewModel)
                        .padding(.horizontal, 16)
                }

                // Bottom info bar
                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                
                Spacer()
            }

            if case .completed(let stars) = viewModel.gameState {
                VStack {
                    Spacer()
                    CircuitResultView(
                        viewModel: viewModel,
                        stars: stars,
                        onDone: {
                            dismiss()
                        },
                        onNextLevel: nextLevelAction.map { advance in
                            {
                                advance()
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
                }
                .onAppear {
                    saveCompletionIfNeeded()
                }
                .animation(.spring(response: 0.4), value: viewModel.gameState == .inProgress)
            }

            // Gave up overlay
            if viewModel.gameState == .gaveUp && !viewModel.showingSolution {
                CircuitGaveUpOverlay(viewModel: viewModel, saveAndDismiss: {
                    saveGiveUpIfNeeded()
                    dismiss()
                })
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                levelLabel
                
                Button("How to Play", systemImage: "questionmark.circle") {
                    showingTutorial = true
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .labelStyle(.iconOnly)
            }
        }
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

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            // Timer
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.timerString)
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            Spacer()

            if viewModel.gameState == .inProgress {
                HStack(spacing: 8) {
                    // Undo
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        viewModel.undoToLastBranch()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 40, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(accentColor.opacity(0.1)))
                    .labelStyle(.iconOnly)

                    // Reset
                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        viewModel.reset()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.6))
                    .frame(width: 40, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.primary.opacity(0.07)))
                    .labelStyle(.iconOnly)

                    // Give Up
                    Button("Give Up", systemImage: "flag.fill") {
                        showGiveUpAlert = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.7))
                    .labelStyle(.titleAndIcon)
                }
            }

            if viewModel.gameState == .gaveUp {
                Button("View Solution", systemImage: "eye.fill") {
                    viewModel.showSolution()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
                .labelStyle(.titleAndIcon)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Terminal progress
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentColor)
                Text("\(viewModel.poweredTerminalCount)/\(viewModel.level.terminalPairs.count) powered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Coverage meter
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(Int(viewModel.coveragePercent * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var navigationTitle: String {
        viewModel.isDaily ? "Circuit · Daily" : "Circuit"
    }

    private var levelLabel: some View {
        Group {
            if let id = viewModel.activeLevelId {
                Text("Level \(id)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var nextLevelAction: (() -> Void)? {
        guard let currentId = viewModel.activeLevelId else { return nil }
        let nextId = currentId + 1
        guard CircuitLevelLoader.level(for: nextId) != nil else { return nil }
        return {
            hasSavedResult = false
            viewModel = CircuitGameViewModel(levelId: nextId)
        }
    }

    private func saveCompletionIfNeeded() {
        guard !hasSavedResult else { return }
        guard case .completed = viewModel.gameState else { return }

        if viewModel.isDaily,
           PersistenceManager.fetchDailyResult(for: .circuit, on: .now, context: modelContext) != nil {
            hasSavedResult = true
            return
        }

        let result = viewModel.buildGameResult()
        ScoreManager.shared.processAndSaveResult(result, context: modelContext)
        hasSavedResult = true
    }

    private func saveGiveUpIfNeeded() {
        guard !hasSavedResult else { return }

        if viewModel.isDaily,
           PersistenceManager.fetchDailyResult(for: .circuit, on: .now, context: modelContext) != nil {
            hasSavedResult = true
            return
        }

        let result = viewModel.buildGameResult()
        ScoreManager.shared.processAndSaveResult(result, context: modelContext)
        hasSavedResult = true
    }
}

// MARK: - Solution Grid (read-only replay)

private struct CircuitSolutionGridView: View {
    let viewModel: CircuitGameViewModel

    @State private var solutionVM: CircuitGameViewModel?

    var body: some View {
        VStack(spacing: 12) {
            Text("SOLUTION")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(.orange)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(.orange.opacity(0.15)))

            if let vm = solutionVM {
                CircuitGridView(viewModel: vm)
            } else {
                ContentUnavailableView("No Solution Available", systemImage: "xmark.circle")
            }

            Button("Back to Your Board", systemImage: "arrow.uturn.backward") {
                viewModel.hideSolution()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.7))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Capsule().fill(.primary.opacity(0.08)))
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

// MARK: - Gave Up Overlay

private struct CircuitGaveUpOverlay: View {
    let viewModel: CircuitGameViewModel
    let saveAndDismiss: () -> Void

    private let accentColor = Color(red: 0.0, green: 0.78, blue: 1.0)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Gave Up")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text("\(viewModel.poweredTerminalCount) of \(viewModel.level.terminalPairs.count) terminals powered")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)

            // Stats row
            HStack(spacing: 0) {
                StatCell(label: "Time", value: viewModel.timerString)
                Divider().frame(height: 36)
                StatCell(label: "Coverage", value: "\(Int(viewModel.coveragePercent * 100))%")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)

            Divider().padding(.horizontal, 24)

            // Actions
            VStack(spacing: 12) {
                Button {
                    viewModel.showSolution()
                } label: {
                    Label("View Solution", systemImage: "eye.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.orange.opacity(0.12))
                        )
                }

                Button("Exit") {
                    saveAndDismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.primary.opacity(0.07))
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 24)
    }
}

// MARK: - StatCell (shared with CircuitResultView)

struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CircuitGameView(levelId: 1)
    }
}
