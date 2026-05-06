# Game Center & Friends Tab — Design & Implementation Plan

**Owner:** Anu
**Drafted:** 2026-04-22
**Status:** Proposal / pre-kickoff

---

## 1. Context

Prisma already ships a surprising amount of Game Center (GC) scaffolding. The goal of this initiative is to turn that scaffolding into a first-class social layer — a working **Friends tab**, proper **leaderboard browsing**, **head-to-head stats**, and a complete **achievement loop** — without re-architecting what is already wired up.

The two user-visible outcomes are:

1. The Friends tab stops being a "Coming Soon" placeholder and becomes the primary surface for social engagement (who's played today, streaks, head-to-head per game, invite/add).
2. Leaderboards and achievements fully reflect player activity across all 5 games (Signals, Archive, Cargo, Shift, Circuit) with no silent submission gaps.

## 2. What Already Exists (Baseline)

A grounded inventory before proposing new work.

### 2.1 Game Center plumbing

`Prisma/Prisma/Core/Services/GameCenterManager.swift` is the central singleton. It authenticates `GKLocalPlayer.local` on app launch (called from `PrismaApp.swift:39`), exposes `isAuthenticated` and `playerName`, and has submission helpers for scores and achievements. The entitlements file has `com.apple.developer.game-center` enabled.

Ten leaderboard IDs are declared (two per game: `...daily.best` + `...daily.streak`, plus `prisma.local.mastery`) and eight achievement IDs (`first_signal`, `first_archive`, `streak_3/7/30`, `perfect_signal`, `local_25/50/100`).

### 2.2 Score submission pipeline

`Prisma/Prisma/Core/Services/ScoreManager.swift` is the funnel every game result flows through. On daily win it submits both the game-specific "best" metric and the current streak; on any win it submits total local level wins to `localMastery`. Per-game "best" metric today:

| Game    | Daily metric submitted       |
|---------|------------------------------|
| Signals | `guessCount` (lower = better) |
| Archive | `guessCount` (lower = better) |
| Shift   | `guessCount`                  |
| Cargo   | `durationSeconds` (lower = better) |
| Circuit | `durationSeconds`             |

### 2.3 Persistence

SwiftData models already give us everything a friend-comparison view needs locally:

- `GameResult` (`Core/Models/GameResult.swift`) — per-session record, both daily and local, with `score`, `guessCount`, `durationSeconds`, `shareString`, `levelId`.
- `LevelProgress` (`Core/Models/LevelProgress.swift`) — per-level completion / won / best-score.
- `PersistenceManager` — query helpers. CloudKit sync is `.automatic` in the container.
- `StreakManager` — drives the `streak_*` achievements and the streak leaderboard.

### 2.4 UI surface

`ContentView.swift` has three tabs: **Games**, **Friends**, **You**. The Friends tab today is `FriendsPlaceholderView.swift` (static "Coming Soon"). The **You** tab already has `LeaderboardView.swift` — a functioning GKLeaderboard browser with game pickers, scope picker, authenticated/unauthenticated states, and a "Your rank" section.

## 3. Known Gaps & Bugs (must fix before or during this work)

Items that would cause silent failure or user confusion once the Friends tab goes live:

1. **`LeaderboardView.leaderboardID(for:scope:)` is a no-op switch.** Every case returns `...daily.best` regardless of scope. Streak leaderboards are unreachable from the UI and "today vs. all time" only takes effect via `GKLeaderboard.TimeScope`, not the ID. Needs a real mapping including streak IDs.
2. **Achievements are partially unwired.** There are `streak_3/7/30` IDs but I don't see a single report path that fires them after `StreakManager.recordDailyWin(...)`. `local_25/50/100` exist but aren't fed by `ScoreManager` either. `first_archive` exists but there's no `first_cargo/shift/circuit` — achievement coverage per game is uneven.
3. **"Perfect" achievements exist only for Signals.** Cargo perfect-clear, Shift all-words, Circuit 3-star solutions, Archive first-guess don't have achievement IDs yet. Either add them or formally descope.
4. **No friends UI at all.** The only friends-scoped view is the `friends` case in `LeaderboardScope`, which still queries the same global `daily.best` ID. No dedicated friends list, no profile, no head-to-head.
5. **No `GKAccessPoint`.** Apple now recommends a persistent dashboard button for GC access in-app; we rely entirely on Settings-level login.
6. **No friend permission flow.** iOS 14.5+ requires `GKLocalPlayer.loadFriends(...)` to go through the explicit `loadFriendsAuthorizationStatus` flow — we'll need to handle `.notDetermined / .denied / .restricted / .authorized` states.
7. **Daily dedup quirk.** `ScoreManager` only inserts a new daily `GameResult` when one doesn't already exist for that date, which is correct. But score re-submission to GC happens even on the first insert path, not on re-plays — fine for GC (it takes best), but we should verify we're not incorrectly double-counting the streak on same-day replays.
8. **Non-GC-signed-in fallback.** Current behavior shows the "Open Settings" prompt, which is fine for Leaderboards. Friends tab needs a similar graceful gate without breaking stats that can still render from local SwiftData.

## 4. Goals & Non-Goals

### 4.1 Goals

- **G1:** Friends tab shows a live list of the player's GC friends with a one-line "today's status" per friend (daily solved? streak? time).
- **G2:** Tapping a friend opens a per-friend profile with per-game stats (best score/time, streak, head-to-head record vs. me).
- **G3:** Leaderboards in the You tab can be scoped by *friends only*, and can browse both `...best` and `...streak` IDs per game.
- **G4:** Every daily win + every local mastery milestone fires the correct achievement across all 5 games — no silent misses.
- **G5:** Graceful degradation — unauthenticated users see a single "Sign in to Game Center" CTA on the Friends tab and in the profile view (mirror of LeaderboardView's unauthenticated branch).
- **G6:** `GKAccessPoint` enabled app-wide so players can open the native GC dashboard from any screen.

### 4.2 Non-goals (for this slice)

- In-app chat / messaging (use native GC invites + iMessage share links only).
- Custom avatars or display names — lean on `GKLocalPlayer.displayName` / `asyncImage`.
- Live multiplayer / turn-based — we're single-player-with-leaderboards only.
- Custom friends-of-friends graph — Apple exposes direct friends only; no transitive discovery.
- Server backend — everything stays on-device + GC + CloudKit.

## 5. Proposed Architecture

Layered so the Friends tab doesn't have to care about GKLeaderboard wiring.

### 5.1 New service layer

`Core/Services/FriendsService.swift` — an `@Observable @MainActor` singleton mirroring `GameCenterManager`. Responsibilities:

- Own `loadFriendsAuthorizationStatus` / `loadFriends` state machine.
- Cache a `[GKPlayer]` of the player's friends, refresh on demand.
- Expose `friendStats(for: GKPlayer, game: GameType) async throws -> FriendGameStats` by reading the friend's entries on each relevant leaderboard.
- Expose `headToHead(against: GKPlayer, game: GameType) async throws -> HeadToHead` which compares my best entry vs. the friend's best entry across the `best` and `streak` boards.
- Provide a `todaySummary(for: GKPlayer) async throws -> FriendTodaySummary` for the Friends tab row (all 5 games' today-scope ranks/scores at once, issued as a batched `GKLeaderboard.loadEntries` with a friends player-scope, single round trip where possible).

Why a new service rather than extending `GameCenterManager`: keeps auth/state concerns separate from query concerns, and makes the friends feature unit-testable by injecting a protocol-backed version.

### 5.2 New data types (in `Friends` feature folder)

```swift
struct FriendGameStats {
    let game: GameType
    let bestTodayRank: Int?
    let bestTodayScore: Int?
    let bestAllTimeRank: Int?
    let currentStreak: Int
}

struct FriendTodaySummary {
    let player: GKPlayer
    let perGame: [GameType: FriendGameStats]   // today scope
    var hasSolvedToday: Bool { perGame.values.contains { $0.bestTodayScore != nil } }
    var gamesSolvedToday: Int { perGame.values.filter { $0.bestTodayScore != nil }.count }
}

struct HeadToHead {
    let game: GameType
    let my: FriendGameStats
    let theirs: FriendGameStats
    var winner: GKPlayer? { /* …compare best metrics; nil on tie */ }
}
```

### 5.3 New views (under `Prisma/Features/Friends/`)

- `FriendsTabView.swift` — replaces `FriendsPlaceholderView`. Top: header + my streak summary. List: one `FriendRow` per GC friend, sorted by "most active today" (games solved today desc, then streak desc). Empty state if no friends. Auth gate if unauthed.
- `FriendRow.swift` — avatar (`GKPlayer.loadPhoto(for: .small)`), display name, today's "X/5 solved" pill, per-game mini-icons colored by whether they've solved today.
- `FriendProfileView.swift` — opens from `FriendRow` tap. Header with avatar/name, grid of five game-stat cards using `FriendGameStats`, and a head-to-head strip ("You: 42 · Them: 39 · 7-day series ↔"). Share button to send a "Challenge in Prisma" link.
- `FriendsAuthGateView.swift` — the empty-state/permission-request view for unauthed or `.notDetermined` friend-loading status.

### 5.4 Leaderboard view upgrades (in place, not new file)

Fix `LeaderboardView.leaderboardID(for:scope:)` so it returns the right ID for the selected *metric* (best vs. streak) and defer scope filtering to `GKLeaderboard.TimeScope`/`PlayerScope`. Add a second picker (`Metric: Best | Streak`) above the existing scope segmented control.

### 5.5 Achievements audit

Centralize achievement reporting in `ScoreManager.reportAchievements(for: result, totalLocalWins:)`:

- On any daily win: check and report `first_{game}` (add missing IDs for cargo/shift/circuit).
- On streak milestones: fire `streak_3`, `streak_7`, `streak_30` whenever the new streak crosses those thresholds.
- On perfect/special events per game: `perfect_signal` (guessed in 1), `perfect_archive` (guessed in 1), `perfect_cargo` (100% fill), `perfect_shift` (all words, no undos), `perfect_circuit` (3-star in target moves).
- On local mastery thresholds: fire `local_25/50/100` as `totalLocalWins` crosses each.

Adding achievement IDs requires a matching change on App Store Connect — listed as an open question below.

## 6. Phased Delivery Plan

Each phase is sized to be shippable on its own. The ordering lets us ship leaderboard fixes before exposing friends UI.

### Phase 0 — Foundation fixes (tiny, ~0.5 day)

1. Fix `LeaderboardView.leaderboardID` scope/metric mapping + add metric picker.
2. Wire `streak_3/7/30` and `local_25/50/100` reports in `ScoreManager` via the new `reportAchievements(for:totalLocalWins:)` helper.
3. Add `first_{game}` achievement IDs for cargo/shift/circuit (after ASC config).
4. Add `GKAccessPoint` enablement behind a setting (default on) in `PrismaApp.swift`.

### Phase 1 — FriendsService + Auth gate (~1 day)

1. Create `Core/Services/FriendsService.swift` with the auth state machine and a stubbed friend list.
2. Replace `FriendsPlaceholderView` with `FriendsTabView` that currently only shows the auth gate + "no friends yet" empty state.
3. Handle `loadFriendsAuthorizationStatus` explicitly; present the system authorization sheet on first entry.
4. Wire "Pull to refresh" against `friendsService.loadFriends()`.

### Phase 2 — Friend list rendering (~1 day)

1. Implement `FriendRow` including `loadPhoto(for:)` with local in-memory cache keyed by `gamePlayerID`.
2. Implement `todaySummary(for:)` with a batched leaderboard query (prefer one `GKLeaderboard.loadEntries(...)` call per leaderboard with `PlayerScope.friendsOnly`; reduce round trips).
3. Sort + render the Friends tab list; add skeleton / loading states.

### Phase 3 — Friend profile & head-to-head (~1.5 days)

1. `FriendProfileView` with per-game `FriendGameStats` cards reading streak + best from respective leaderboards.
2. Head-to-head strip. Define "winner" precisely per game (lower-is-better vs. higher-is-better) — write down those rules in a small `MetricDirection` enum.
3. Share/challenge button — `ShareLink` with a deep-link URL (e.g. `prisma://challenge?game=signals&date=YYYY-MM-DD`). Deep-link handler is a stretch goal — could just open the game.

### Phase 4 — Stats dashboard integration (~0.5 day)

1. Add a "Top friend this week" card to the You-tab `ProfileView` using `FriendsService`.
2. Add a "Friends" segment toggle to existing charts if/when it's cheap.

### Phase 5 — Testing, QA, & polish (~1 day)

1. Unit tests for `FriendsService` via a mock `GKLeaderboardLoading` protocol.
2. Manual QA matrix: signed-out, signed-in-no-friends, signed-in-many-friends, denied-friend-permission, airplane-mode.
3. Visual polish: empty states, loading skeletons, error messaging.
4. Dark mode + dynamic type pass (existing `AppTheme` usage).

**Target total:** ~5 working days spread across phases; Phase 0 can land ahead of the rest if desired.

## 7. Testing Strategy

- **Unit**: `FriendsService` should be protocol-driven around a `GKLeaderboardLoading` facade we own, so tests can return canned `GKLeaderboard.Entry`-shaped fixtures without hitting the network. Cover: sort order, auth transitions, head-to-head tie rules.
- **Snapshot**: key empty/loading/populated states of `FriendsTabView` and `FriendProfileView`.
- **Integration**: live in the GC sandbox with two test Apple IDs as mutual friends; run the matrix in Phase 5.
- **Regression**: extend existing test targets (don't create a new one); add a `FriendsServiceTests.swift`. For CI, guard live-GC tests behind a skip token so we don't break builds offline.

## 8. Risks & Constraints

- **GC sandbox vs. production is a real pain.** Scores posted in sandbox are separate from prod. We must test with sandbox Apple IDs; achievements granted in sandbox don't transfer. Document this in the test plan so we don't waste time chasing "missing" scores.
- **`loadFriends` permission is one-shot.** If the user denies it, re-requesting requires Settings. The UI must make it recoverable without making users feel trapped.
- **App Store Connect leaderboard / achievement config must land before app code.** Adding new IDs without ASC setup yields silent failures (the SDK logs but doesn't throw visibly).
- **Rate limits.** `GKLeaderboard.loadEntries` is not generous. Batch per-leaderboard rather than per-friend; cache aggressively (memoize today-scope results for ~60s).
- **CloudKit** — We use `.automatic` sync on `GameResult` / `LevelProgress`. For the "head-to-head" view we intentionally do NOT try to read the friend's SwiftData — only Game Center data. No cross-user CloudKit sharing needed for this phase.
- **Identity mismatch.** Players who change their GC display name mid-series show a different name than their historic entries. Acceptable; noted.

## 9. Open Questions (need Anu's input before coding)

1. **Daily metric direction.** Signals/Archive/Shift today submit `guessCount` (lower = better) to `daily.best`. For friend head-to-head we need a canonical winner rule per game — confirm lower-is-better for guess-based games and time-based for Cargo/Circuit, and what "tie" means (both solved, same guesses — does time break the tie?).

   - For signals, lower guess count is better and time breaks tie.
   - For shift, lower move count is better and time breaks tie.
   - For archive, lower guess count is better and time breaks tie.
   - For cargo, full board completition and lower time is better.
   - For circuit, full board completition and lower time is better.

2. **Achievement set expansion.** Do you want the per-game firsts (`first_cargo/shift/circuit`) and the `perfect_*` set added this slice? Each new ID requires ASC configuration — say the word and I'll produce the exact list for you to paste into ASC. - yes please do so
3. **Friends-tab sort order.** I suggest (games-solved-today desc, then current longest streak desc, then display name). Happy with that, or should solved-today always sink if they've not played today? - yes solved today should always sink if they've not played today
4. **Invite / challenge flow.** Is a simple `ShareLink` with a `prisma://challenge?...` URL enough, or do you want native `GKMatchmakerViewController` friend-invite integration? I'd recommend ShareLink + iMessage for a puzzle-game shape. - this seems good enough happy with this approach.
5. **`GKAccessPoint` placement.** Top-leading across all screens is Apple's default; do you want it scoped only to You + Friends tabs to keep game screens distraction-free? - yes i like this approach
6. **Fallback when GC unavailable.** If the user never signs into GC, should the Friends tab show an inert "sign in" state, or do you also want a fully local "you only" stats page that works offline? - lets have a sign in option instead of a you only page
7. **CloudKit sharing.** Out-of-scope per above — confirm? Re-scoping would add ~2 weeks and significant complexity. - confirmed out of scope for now
8. **Where should the "open Leaderboards" deep-link live?** Today it's in You tab; should the Friends tab also have a shortcut to the GC native dashboard for the same metrics? - not needed

## 10. Out-of-the-box things we'll rely on

- `GKAccessPoint.shared.isActive = true`
- `GKLocalPlayer.local.loadFriends(authorizationStatus:)`
- `GKLeaderboard.loadLeaderboards(IDs:)` and `GKLeaderboard.loadEntries(for:timeScope:range:)`
- `GKPlayer.loadPhoto(for: .small)`
- `GKAchievement.report(_:)`
- Existing `AppTheme`, `AppTheme.accent(for:)`, `AppTheme.appBackground()`

## 11. Rollout / Flagging

No feature flag — this ships behind the existing Friends tab. The tab is discoverable but the *features* within are hidden until GC authentication succeeds. That matches how the existing LeaderboardView handles auth today, and gives us a clean "just works" experience for authenticated users without risking the unauthenticated case.

---

*Once the open questions in §9 are answered, the plan can be resequenced into concrete tickets and the Phase 0 foundation fixes can land first in a small PR to de-risk the rest.*
