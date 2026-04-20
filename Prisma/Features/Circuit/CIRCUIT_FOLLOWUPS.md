# Circuit — Follow-up TODO

Tracking for UX / polish / content items deliberately **out of scope** for the 100-level + gate-split + chapter-map bundle shipped 2026-04-20. Each item below has a rough shape and a rationale for being deferred — feel free to rework before picking up.

## UX / gameplay polish

### Undo + redo deepening
- Current state: `Undo` button truncates back to the last branch point (`undoToLastBranch()`).
- Desired: multi-step undo stack (1 step per cell extension) AND a redo stack that survives until a new branch is drawn.
- Shape: maintain a ring buffer of `CircuitState` snapshots keyed to the viewModel. Probably 32 deep. Flush on `reset()` / `giveUp()`.
- Why deferred: tuning the granularity (undo one cell vs. one segment vs. one branch) needs user testing, and the current single-step undo is sufficient for the typical solve.

### Color-blind mode
- Problem: the 6-color palette (blue/red/yellow/purple/orange/green) fails deuteranopia and protanopia — particularly red/orange and green/yellow are indistinguishable.
- Desired: alternative palette with shape/pattern differentiation (e.g., dashed strokes per color, per-color icon inside the terminal ring, or a high-contrast palette toggle).
- Shape: add `AppSettings.colorblindPalette` toggle; `NeonColor.swiftUIColor` reads it; `CircuitCellView.TerminalView` overlays a per-color SF Symbol when enabled.
- Why deferred: designing a palette that preserves the "neon" aesthetic while reaching WCAG AA contrast is a design-led piece of work, not a quick code change.

### Hint system
- Desired: after 90 seconds of no progress, the "How to Play" button grows a pulse and tapping it surfaces an escalating hint (1 — which colors need what signals, 2 — which gate is load-bearing, 3 — partial segments of the canonical solution).
- Shape: add `CircuitGameViewModel.hintLevel: Int` with a timer; hints are read from `CircuitLevelLoader` + `solutionStateJSON`.
- Why deferred: needs careful balance so the hint doesn't become a shortcut. Should also be opt-in per-player.

### Par time + star-rating on time
- Current state: stars are based on score tiers (coverage + time + gate interactions).
- Desired: show an explicit "par time" for each chapter and a time-based star tier on the Result screen.
- Shape: add `par_seconds` to each level (can be derived heuristically from `solutionStateJSON` length × a per-chapter constant). Surface in `CircuitResultView`.
- Why deferred: par times need playtesting before shipping — without that they'll mislead players.

### Replay view (animated)
- Desired: after a win, tap "Watch Replay" on the Result screen to re-animate the solved path at ~1 cell/40 ms. Useful for learning alternate solutions.
- Shape: `CircuitGameView` already has a read-only `CircuitSolutionGridView`; extend it with an animated path-append mode using `TimelineView`.
- Why deferred: nice-to-have; doesn't unblock any other work.

### First-time-gate tutorial pop-ins
- Desired: the first time a player reaches a level containing a gate type they haven't seen before, a lightweight overlay ("This is the Spark — it turns inactive signals on.") appears over the board and dismisses on tap.
- Shape: extend `CircuitTutorialView` with gate-specific entry points; trigger from `CircuitGameView.onAppear` guarded by `@AppStorage("circuit_seen_gate_\(rawValue)")` per gate type.
- Why deferred: the "How to Play" sheet + tap-gate tooltip already carry the vocabulary. First-time pop-ins are nicer but not blocking.

## Authoring + tooling

### Level editor / visualizer
- Desired: a debug-only in-app view that renders a level's `solutionStateJSON` as an animated replay — makes reviewing new levels orders of magnitude faster than running unit tests.
- Shape: hook it to a long-press on a level cell in `LevelSelectorView` when `#if DEBUG`.

### Automated solvability audit
- Current state: `CircuitLevelLoaderTests.allCuratedSolutionsReplayToSolvedState()` proves the *canonical* solution wins. It does **not** prove the level is solvable only via that canonical path.
- Desired: a BFS/DFS solver that verifies (a) at least one solution exists and (b) trivial solutions are blocked (a level that can be won by ignoring the Synthesizer shouldn't ship).
- Shape: `scratch/solve.py` — pure Python, mirrors the Swift simulator. Run against `circuit_levels.json` pre-merge.

### Difficulty-curve telemetry
- Desired: log win rate + median solve time per level so the 100-level ordering can be tuned by data rather than guesswork. Spotting a "cliff" at L47 means we should demote that level's difficulty or move it later.
- Shape: existing `ScoreManager` events are enough; add a `level_solve_timing` event on win and surface aggregated win-rate-per-level in an internal dashboard.

## Known gaps in shipped bundle

- The completion haptic is gated on `stars >= 2` for the success notification. 1-star wins get a medium impact only. Worth reviewing after playtest feedback.
- Tap-gate tooltip uses `offset(_:)` positioning that can clip near edges on very small phones. Tested on iPhone 15 Pro simulator — verify on SE-class screens before the next App Store submission.
- The generic `LevelSelectorView` now drives all 100 Circuit levels. Because it's shared across games it doesn't surface Circuit-specific hints (e.g., "this level introduces the Spark gate"). A per-level badge on the tour levels (L1–L10) would help readability.

## Reference

- `CHAPTER_PLAN.md` — chapter structure + level-design invariants.
- `GRID_DESIGN.md` — authoring rubric, solution JSON schema.
- `FIX_PLAN.md` — historical log of the save-state + L6/L10/L16/L20/L21/L25 fixes.
- `scratch/build_catalog.py` — the 100-level generator that writes `Resources/circuit_levels.json`.
- `scratch/validate_catalog.py` — Python-side replay validator that mirrors `allCuratedSolutionsReplayToSolvedState()`.
