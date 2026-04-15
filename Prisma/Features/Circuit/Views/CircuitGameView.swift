//
//  CircuitGameView.swift
//  Prisma
//
//  Full-screen Circuit game view.
//  Hosts the toolbar (timer, undo, reset), the CircuitGridView, and the
//  CircuitResultView overlay when the game is complete.
//

import SwiftUI
import SwiftData

struct CircuitGameView: View {
    @State private var viewModel: CircuitGameViewModel
    @State private var hasSavedResult = false
    @State private var showingTutorial = false
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

                // Grid
                CircuitGridView(viewModel: viewModel)
                    .padding(.horizontal, 16)

                // Bottom info bar
                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                if viewModel.allTerminalsPowered && viewModel.allWaypointsVisited && !viewModel.isGameOver && viewModel.coveragePercent < 1.0 {
                    Button {
                        viewModel.forceFinish()
                    } label: {
                        Text("Finish Anyway (\(viewModel.calculateStarRating()) ★)")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.circuit))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                
                Spacer()
            }

            // Result overlay
            if case .completed(let stars) = viewModel.gameState {
                VStack {
                    Spacer()
                    CircuitResultView(
                        viewModel: viewModel,
                        stars: stars,
                        onDone: {
                            saveCompletionIfNeeded()
                            dismiss()
                        },
                        onNextLevel: nextLevelAction.map { advance in
                            {
                                saveCompletionIfNeeded()
                                advance()
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
                }
                .animation(.spring(response: 0.4), value: viewModel.gameState == .inProgress)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    levelLabel
                    Button {
                        showingTutorial = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTutorial) {
            CircuitTutorialView()
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

            // Undo
            Button {
                viewModel.undoToLastBranch()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 40, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(accentColor.opacity(0.1)))
            }
            .disabled(viewModel.isGameOver)

            // Reset
            Button {
                viewModel.resetLevel()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.6))
                    .frame(width: 40, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.primary.opacity(0.07)))
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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CircuitGameView(levelId: 1)
    }
}
