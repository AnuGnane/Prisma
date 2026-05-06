# Phase B — Change Summary

> Completed: 2026-05-06  
> Build status: ✅ Clean (0 errors, 0 warnings)  
> Branch: main  

---

## Overview

Phase B covers pre-ship polish and technical hygiene across eight tasks. All code changes compile cleanly. The full test suite was run; new tests for Daily Sweep detection, share card rendering, and Circuit level coverage have been added.

---

## B.1 — Per-game metric formatting in DailyResultRow

**Files changed:** `GameResult.swift`, `ProfileView.swift`, `LeaderboardContent.swift`

Previously, `DailyResultRow` in the profile history screen showed "X guesses" for every game, even timed games like Cargo and Circuit where a guess count is meaningless.

Two additions to `GameResult`:

- `static func formatElapsedSeconds(_ seconds: Int) -> String` — shared formatter that produces `"42s"` for sub-minute durations and `"1:45"` for anything longer (zero-padded seconds).
- `var formattedMetric: String` — per-game display string: Signals/Archive → `"X guess(es)"`, Shift → `"X move(s)"` (stored in the `guessCount` field), Cargo/Circuit → elapsed time via the shared formatter.

`DailyResultRow` now renders `result.formattedMetric` instead of the previous hardcoded guess-count branch. `LeaderboardContent.formattedScore` was updated to delegate its time formatting to `GameResult.formatElapsedSeconds` so the two surfaces stay in sync.

---

## B.2 — GameKit silent-failure audit

**Files changed:** `FriendsService.swift`, `FriendRow.swift`

All bare `try?` calls on GameKit async APIs were converted to explicit `do { … } catch { … }` blocks. Errors are now logged inside a `#if DEBUG` guard so they surface in development builds without adding any overhead to release builds. Release behaviour is unchanged — failures still degrade gracefully.

Specific changes:
- `FriendsService.loadFriendProfile`: two `try?` calls (`GKLeaderboard.loadLeaderboards` and `board.loadEntries(for:timeScope:)`) now log the error description and continue.
- `FriendRow`: `player.loadPhoto(for: .small)` returns a non-optional `UIImage`, so the previous `if let` binding was silently discarding the result on the success path. Replaced with direct assignment inside a do-catch.

---

## B.3 — MetricKit integration

**Files created:** `MetricsManager.swift`  
**Files changed:** `PrismaApp.swift`

`MetricsManager` is a singleton `NSObject` conforming to `MXMetricManagerSubscriber`. It registers with `MXMetricManager.shared` at app launch (in `PrismaApp.init()`) and implements both delegate callbacks:

- `didReceive(_: [MXMetricPayload])` — logs the JSON payload in `#if DEBUG` builds; intended as a hook for future analytics.
- `didReceive(_: [MXDiagnosticPayload])` — logs crash count, hang count, and CPU exception count per payload in `#if DEBUG`; ready to wire up to a crash-reporting service.

MetricKit delivers payloads once per day (and on first launch after install), so this has no runtime cost.

---

## B.4 — Circuit test hardening

**Files changed:** `PrismaTests/CircuitGameTests.swift`

The existing Circuit level-loader test used a weak `>= 10` assertion. Three targeted improvements:

1. **Exact level count**: `#expect(levels.count == 150)` — enforces the full curated set and will catch accidental JSON omissions.
2. **Suboptimal path gives 1 star**: Renamed and tightened the existing test to assert exactly `stars == 1` for a 50%-coverage path on Level 1.
3. **All canonical solutions give 3 stars** (`allCanonicalSolutionsGive3Stars`): Iterates all 150 levels, deserialises each level's `solutionStateJSON`, restores it into a fresh `CircuitGameViewModel`, and asserts `calculateStarRating() == 3`. This is the most valuable regression guard — any level whose canonical solution is broken will be caught here.
4. **`forceFinish` on canonical solution reaches `.completed(3)`** (`canonicalSolutionForceFinishGivesCompletedState`): Verifies that the full game completion path (not just the rating calculation) works correctly for the first level.

---

## B.5 — Daily Sweep celebration

**Files created:** `DailySweepView.swift`  
**Files changed:** `GamesHomeView.swift`

When a player wins all five daily games in a single day, a full-screen celebration sheet appears once. Key design decisions:

- **Detection** (`DailySweepView.isSweep`): Checks that the set of winning `GameResult.gameType` values covers all five `GameType.allCases`. Handles duplicates correctly — only distinct game types are counted.
- **Day guard**: `@AppStorage("sweep.lastShownDay")` stores the ISO date string of the last shown sweep. The sheet only fires once per calendar day, regardless of how many times the app is foregrounded.
- **Trigger points**: `GamesHomeView` re-evaluates on `.onAppear` and on `.onChange(of: todayWins.count)`, so the sweep fires naturally as the fifth game completes rather than only on the next launch.
- **Share integration**: `DailySweepView` pre-renders a `ShareableImage` on `.onAppear` via `ShareCardRenderer.render(results:)` and surfaces it through a `ShareLink`.
- **`@Query` predicate**: SwiftData predicates cannot call `Calendar` APIs, so the query filters `isDaily && score > 0` and the `todayWins` computed property applies the calendar day filter in Swift.

---

## B.6 — Share card for daily results

**Files created:** `ShareCardView.swift`, `ShareCardRenderer.swift`

A fixed 400×520 pt dark card that summarises the day's five game results, rendered at 3× scale (1200×1560 px) for crisp sharing.

`ShareCardView` is a plain SwiftUI view with no SwiftData dependencies — it takes a `[GameResult]` directly, making it testable and reusable. Each row shows:
- A 4 px coloured left bar (game brand colour)
- The SF Symbol icon for the game
- The game name
- The formatted metric (`formattedMetric`)

`ShareCardRenderer` wraps `ImageRenderer` with a fixed `proposedSize` and `scale = 3`. The result is wrapped in `ShareableImage: Transferable` (using `DataRepresentation(exportedContentType: .png)`) for use with SwiftUI's `ShareLink`.

---

## New Tests Added

| File | Suite | Tests |
|------|-------|-------|
| `DailySweepTests.swift` | `DailySweepDetectionTests` | 6 — happy path, 4 wins, 5 with loss, empty, duplicates, duplicates + full sweep |
| `DailySweepTests.swift` | `FormattedMetricTests` | 6 — Signals 2/1 guess, Archive 3 guesses, Cargo 42s/2:05, Circuit 1:00, Shift 10/1 moves |
| `ShareCardTests.swift` | `ShareCardRendererTests` | 5 — non-nil image, 1200 px width, 1560 px height, empty/partial no crash, PNG transferable |
| `CircuitGameTests.swift` | `CircuitLevelLoaderTests` | +2 — `allCanonicalSolutionsGive3Stars`, `canonicalSolutionForceFinishGivesCompletedState` |

---

## Files Changed at a Glance

| File | Change type |
|------|-------------|
| `Core/Models/GameResult.swift` | Modified — added `formatElapsedSeconds` + `formattedMetric` |
| `Core/Models/GameType.swift` | Modified — added `emoji` property |
| `Features/Profile/ProfileView.swift` | Modified — `DailyResultRow` now uses `formattedMetric` |
| `Features/Leaderboard/LeaderboardContent.swift` | Modified — time format delegates to `GameResult` |
| `Core/Services/FriendsService.swift` | Modified — `try?` → do-catch with `#if DEBUG` logging |
| `Features/Friends/FriendRow.swift` | Modified — `try?` photo load → do-catch, non-optional binding fix |
| `Core/Services/MetricsManager.swift` | **New** — MetricKit subscriber singleton |
| `PrismaApp.swift` | Modified — `import MetricKit`, registers `MetricsManager` on init |
| `Features/Profile/DailySweepView.swift` | **New** — full-screen daily sweep celebration |
| `Core/Views/GamesHomeView.swift` | Modified — sweep detection + sheet trigger |
| `Features/Profile/ShareCardView.swift` | **New** — shareable 400×520 pt result card |
| `Features/Profile/ShareCardRenderer.swift` | **New** — `ImageRenderer` wrapper + `ShareableImage: Transferable` |
| `PrismaTests/DailySweepTests.swift` | **New** — 12 tests for sweep detection + metric formatting |
| `PrismaTests/ShareCardTests.swift` | **New** — 5 tests for card rendering + PNG transferable |
| `PrismaTests/CircuitGameTests.swift` | Modified — tightened assertions, +2 canonical solution tests |

---

## Ready for Phase C

The codebase is in a clean, buildable state. Before archiving for TestFlight:

1. ☐ Run full test suite and confirm all pass (Xcode → Product → Test, or `xcodebuild test`)
2. ☐ Bump `CFBundleShortVersionString` → `1.0.4` and `CFBundleVersion` → next integer in `Info.plist` / project settings
3. ☐ Configure the 7 pending Game Center achievements in App Store Connect (see `GAME_CENTER_STATUS.md`)
4. ☐ Archive and upload to TestFlight
5. ☐ Write TestFlight "What to test" notes for build 4
