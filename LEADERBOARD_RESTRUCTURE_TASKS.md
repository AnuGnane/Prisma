# Leaderboard Restructure — Task Tracker

**Plan doc:** `LEADERBOARD_RESTRUCTURE_PLAN.md`
**Started:** 2026-04-23
**Status legend:** ☐ not started · ◐ in progress · ✅ done · ⚠️ blocked · ✂️ dropped · ⏸ postponed (deliberate)

Update this file **as work lands**, not retroactively. Each task: status, short note if context helps. No silent progress.

---

## Phase 1 — Tab restructure

| # | Task | Status | Notes |
|---|---|---|---|
| 1.1 | Create `Features/Leaderboard/` group in Xcode project | ✅ | Created 2026-04-23 |
| 1.2 | Extract `LeaderboardView` body → `LeaderboardContent` (no `NavigationStack`) | ✅ | New file at `Features/Leaderboard/LeaderboardContent.swift`. Supporting types (`LeaderboardEntry`, `LeaderboardScope`, `LeaderboardMetric`, `GamePickerChip`, `RankRow`) moved here to avoid duplicate declarations. Old `LeaderboardView.swift` reduced to a 29-line wrapper. |
| 1.3 | Extract `FriendsTabView` body → `FriendsListContent` (no `NavigationStack`) | ✅ | New file at `Features/Leaderboard/FriendsListContent.swift`. The `GKPlayer: Identifiable` retroactive conformance moved here; old `FriendsTabView.swift` reduced to a 32-line wrapper. |
| 1.4 | Create `LeaderboardTabView.swift` with `@SceneStorage("leaderboardSegment")` + segmented picker | ✅ | Owns `GKAccessPoint` lifecycle via `.onAppear`/`.onDisappear` |
| 1.5 | Rewire `ContentView.swift` — rename tab to "Leaderboard", icon `trophy.fill`, root = `LeaderboardTabView()` | ✅ | Moved GKAccessPoint toggle into `LeaderboardTabView` itself so both segments see the dashboard button |
| 1.6 | Delete `gameCenterPlaceholder` block in `ProfileView.swift` | ✅ | Removed both the call site and the method definition |
| 1.7 | Delete `showLeaderboards` from `ProfileSectionPreferences.swift` + remove `profile.showLeaderboards` UserDefaults key | ✅ | Added one-time `UserDefaults.removeObject(forKey:)` in `init()` to clean existing installs |
| 1.8 | Delete "Leaderboards" row from `ProfileCustomizeSheet.swift` | ✅ | |
| 1.9 | Build cleanly (`XcodeBuild`) | ✅ | Anu confirmed local cmd-B is clean (2026-04-25). |
| 1.10 | Manual smoke test on simulator: tab renames, segment switches, friend row opens profile, preview compiles | ☐ | Rolled into Phase 2 task 2.8 — single smoke pass after the dead-code removal. |

## Phase 2 — Streak UI cleanup + dead-code removal

Scope expanded 2026-04-25 after audit found streak writes in 4 files (not 1) and `FriendsService` still reads streak boards (locked decision says "streaks not shown in UI" — implies friend-streak data is also out).

| # | Task | Status | Notes |
|---|---|---|---|
| 2.1 | Remove Metric picker from `LeaderboardContent.swift` | ✅ | Dropped `@State selectedMetric`, the `Picker`, the `.task(id: selectedMetric)`, and the `enum LeaderboardMetric`. |
| 2.2 | Simplify `leaderboardID(for:)` to drop `metric:` arg, always return `...daily.best` | ✅ | Helper now takes a single `GameType` and returns `...daily.best`. |
| 2.3 | Delete `challengeButton` method + call site in `FriendProfileView.swift` | ✅ | Both gone; header doc updated; padding migrated to the per-game cards container. |
| 2.4 | Delete `Features/Profile/LeaderboardView.swift` wrapper | ✅ | XcodeRM 2026-04-25; preview lives in `LeaderboardContent.swift`. |
| 2.5 | Delete `Features/Friends/FriendsTabView.swift` wrapper | ✅ | XcodeRM 2026-04-25; preview lives in `FriendsListContent.swift`. `GKPlayer: Identifiable` retroactive conformance already migrated to `FriendsListContent.swift` in Phase 1. |
| 2.6 | Remove streak `submitScore` writes from `ScoreManager`, `CargoGameView`, `ArchiveGameView`, `SignalsGameView` (do NOT touch `StreakManager`) | ✅ | All four sites cleaned. `StreakManager.recordDailyWin(...)` calls preserved — they still drive the streak_3/7/30 achievements via local counts. |
| 2.6b | Remove streak reads from `FriendsService` + `currentStreak`/`streakRank` from `FriendGameStats` + flame badge from `FriendProfileView`'s `GameStatCard` + `streak`/`maxStreak` from `FriendTodayEntry`/Summary | ✅ | Streak loads removed from `loadTodaySummaries`/`loadFriendProfile`/`headToHead`; `streakLeaderboardID(_:)` deleted; `FriendGameStats` slimmed to `bestAllTimeScore`+`bestAllTimeRank`; `FriendTodayEntry` slimmed to `score`+`rank`; `FriendTodaySummary.maxStreak` removed (sortedFriends sort tier 3 now alphabetical); `HeadToHead.outcome` no longer falls back to streak tiebreak. |
| 2.6c | Delete dead `Features/Friends/FriendsPlaceholderView.swift` | ✅ | XcodeRM 2026-04-25. |
| 2.6d | Test alignment: drop streak ID from `AsyncServiceTests` mock submission; refactor `GameCenterIntegrationTests.bestAndStreakDistinct` to constant comparison instead of `FriendsService.streakLeaderboardID` (which is being deleted) | ✅ | `AsyncServiceTests` now submits `signalsDailyBest` + `localMastery` (preserves multi-ID coverage). `uniqueStreakIDs` and `bestAndStreakDistinct` now compare `GameCenterManager.Leaderboard` constants directly. |
| 2.7 | Build cleanly | ✅ | `BuildProject` succeeded in 10.9s, zero errors. |
| 2.8 | Manual smoke test (rolls in 1.10): tab renames, segments, friend row → profile sheet, no metric picker, no challenge button, no streak badges, dailies still submit Best score | ✅ | Anu confirmed all four checks pass on simulator (2026-04-25). Phase 2 closed. |

## Phase 3 — Empty/error-state polish

| # | Task | Status | Notes |
|---|---|---|---|
| 3.1 | Draft `Core/UI/AppEmptyState.swift` (icon, title, message, optional retry closure) | ✅ | New file at `Prisma/Core/UI/AppEmptyState.swift`. Wraps `ContentUnavailableView` with `.neutral` / `.error` style enum, optional action closure + customisable action title. Three previews. |
| 3.2 | **Get Anu's visual sign-off before sweep** | ✅ | Anu approved the helper (2026-04-25) and asked for two leaderboard restructure tweaks rolled in alongside Phase 3 (see decision log). |
| 3.3 | Sweep `LeaderboardContent` — "No scores yet" + error variant | ✅ | Plus full restructure: text-chip game picker → icon row, dropped scope picker, hardcoded `.friendsOnly + .today`, deleted `LeaderboardScope` enum + `GamePickerChip`, unauthenticated branch now also uses `AppEmptyState`. |
| 3.4 | Sweep `FriendsListContent` — no friends + load error | ✅ | `noFriendsEmptyState` collapsed to `AppEmptyState`. New `loadErrorState(message:)` branch in the router so a failed `loadFriends` no longer silently shows the no-friends view. |
| 3.5 | Sweep `FriendProfileView` — load error (with retry) | ✅ | `ContentUnavailableView` → `AppEmptyState` with a Retry action that calls `loadProfile()` again. |
| 3.6 | Sweep `ProfileView.emptyDailySection` — no daily results yet | ✂️ | Deliberately skipped — this is an in-card inline empty state (~120pt tall, sits between other cards). Forcing it through the fullscreen-shaped `AppEmptyState` would visually inflate the card. Add an `inline` style to `AppEmptyState` later if uniformity becomes important. |
| 3.7 | Grep game views for completion error paths — align with helper | ✅ | Only one match found: `CircuitGameView.CircuitSolutionGridView`'s "No Solution Available" `ContentUnavailableView`. Swapped to `AppEmptyState` with explanatory message. |
| 3.8 | Dark-mode + Dynamic Type pass on every swept call site | ☐ | Anu — needs simulator pass. `ContentUnavailableView` adapts to both natively, but the Retry button tint (`AppTheme.error`) and accent contrast worth a manual check. |

## Phase 4 — ASC achievement config

| # | Task | Status | Notes |
|---|---|---|---|
| 4.1 | Write `tools/gen_achievement_icons.swift` — CLI script rendering 512×512 PNGs with SF Symbol + gradient | ✅ | New file at `Prisma/tools/gen_achievement_icons.swift` (single-file `swift` script). Gradients sourced from `AppTheme.{cargo,shift,circuit,archive}Gradient` for visual continuity. README at `tools/README.md` documents run + ASC upload steps. |
| 4.2 | Generate 10 PNGs into `tools/achievement_images/` | ✅ | Anu ran `swift tools/gen_achievement_icons.swift` 2026-04-25 (initial 8) and again after script update added `first_signal` + `first_archive` (now 10). Commit the PNGs alongside the script for reproducibility. |
| 4.3 | Finalise ASC localization strings (EN) for all 10 achievements | ✅ | Final 10-row table below — used by Anu for the first-win uploads. |
| 4.4 | Configure `prisma.first_cargo` in ASC — paste ID, image, localization, 20pt, non-repeatable, not hidden | ✅ | Anu — entry was pre-existing; artwork + localisation uploaded 2026-04-25 (Track A). |
| 4.5 | Configure `prisma.first_shift` in ASC | ✅ | Anu — same as 4.4. |
| 4.6 | Configure `prisma.first_circuit` in ASC | ✅ | Anu — same as 4.4. |
| 4.6a | (NEW) Upload artwork + localisation for pre-existing `prisma.first_signal` and `prisma.first_archive` entries | ✅ | Anu — both completed alongside 4.4–4.6 in Track A. |
| 4.6b | (NEW) Configure `prisma.perfect_signal` in ASC — was assumed pre-existing per stale `GAME_CENTER_STATUS.md`; screenshot confirmed it's **not** there. Icon now generated by Phase 4.1 script. | ⏸ | **Postponed by Anu 2026-04-25.** Not a TestFlight blocker — `gc.reportAchievement(...)` calls silently no-op when the ASC entry is missing. Add post-launch when ready. |
| 4.7 | Configure `prisma.perfect_archive` in ASC — 100pt | ⏸ | Postponed by Anu 2026-04-25. Same rationale as 4.6b. |
| 4.8 | Configure `prisma.perfect_cargo` in ASC — 100pt | ⏸ | Postponed by Anu 2026-04-25. Same rationale as 4.6b. |
| 4.9 | Configure `prisma.perfect_shift` in ASC — 100pt | ⏸ | Postponed by Anu 2026-04-25. Same rationale as 4.6b. |
| 4.10 | Configure `prisma.perfect_circuit` in ASC — 100pt | ⏸ | Postponed by Anu 2026-04-25. Same rationale as 4.6b. |
| 4.11 | Sandbox verify: trigger each first-win achievement, confirm banner fires | ☐ | After ASC propagation. Only the 5 first-wins are live now — perfect-wins deferred to a later pass. |

### Phase 4 — ASC localization draft (review before pasting into ASC)

| ID | Pre-earned title | Pre-earned description | Earned description |
|---|---|---|---|
| `prisma.first_signal` | Tuned In | Complete any Signals puzzle | Read your first signal |
| `prisma.first_archive` | Time Traveller | Complete any Archive puzzle | Found your first historic date |
| `prisma.first_cargo` | Pack Your Bags | Complete any Cargo puzzle at 70% fill or higher | Packed your first Cargo board |
| `prisma.first_shift` | Word Mover | Complete any Shift puzzle | Solved your first Shift |
| `prisma.first_circuit` | Connected | Complete any Circuit puzzle | Completed your first Circuit |
| `prisma.perfect_signal` | Cold Read | Solve Signals in a single guess | Cracked the code in one |
| `prisma.perfect_archive` | Dead Reckoning | Identify the Archive date on your very first guess | Got it in one |
| `prisma.perfect_cargo` | Tetris Mode | Fill every cell on a Cargo board | 100% board fill achieved |
| `prisma.perfect_shift` | No Backsies | Solve a Shift puzzle without using a single undo | Solved zero-undo |
| `prisma.perfect_circuit` | Par Excellence | Solve a Circuit puzzle at or under the par move count | Solved under par |

## Phase 5 — TestFlight readiness

| # | Task | Status | Notes |
|---|---|---|---|
| 5.1 | Bump `MARKETING_VERSION` | ✅ | Already at `1.0` for both Debug + Release configs (suitable for first TestFlight). Bump to 1.0.1 / 1.1 / etc. on subsequent releases. |
| 5.2 | Bump `CURRENT_PROJECT_VERSION` (build number) | ✅ | Bumped from `1` → `2` on 2026-04-25 after the build-1 ASC upload failed validation (icon alpha error 90717). All 5 configs updated. |
| 5.3 | Confirm `PRODUCT_BUNDLE_IDENTIFIER` matches ASC record | ✅ | Confirmed via `asc apps list` 2026-04-25: ASC App ID `6762262232`, bundle ID `AG.Prisma` — exact match with `project.pbxproj`. Internal app name in ASC is "Prisma Brain Games" (App Store display name on the storefront is separately set in App Information; can differ). |
| 5.4 | Confirm deployment target = iOS 18.0 across Debug + Release | ✅ | `IPHONEOS_DEPLOYMENT_TARGET = 18.0` confirmed in both configs of the Prisma target. |
| 5.5 | Add `ITSAppUsesNonExemptEncryption = false` to `Custom-Info.plist` | ✅ | Added 2026-04-25. Skips the export-compliance dialog on every submission. |
| 5.6 | Add `LSApplicationCategoryType = public.app-category.puzzle-games` | ✅ | Changed from `strategy-games` → `puzzle-games` 2026-04-25. Both Debug + Release configs updated. |
| 5.7 | Confirm `CFBundleDisplayName` set to "Prisma" | ✅ | `INFOPLIST_KEY_CFBundleDisplayName = Prisma` confirmed in both configs. |
| 5.8 | Verify `Assets.xcassets/AppIcon` — all sizes populated, esp. 1024×1024 | ✅ | All three 1024×1024 slots filled (light / dark / tinted). On 2026-04-25 the first ASC upload failed with error 90717 (alpha channel on the marketing icon). Light + dark variants flattened to opaque RGB by sampling the matte colour just inside the rounded-corner curve (light: rgb(118, 113, 246), dark: rgb(81, 82, 82)) — visually identical to the originals, just no transparency. Tinted variant intentionally left RGBA because iOS 18 tinted icons are template masks. Original RGBA files preserved alongside as `*.alpha-backup` (delete after Anu confirms the rebuild looks right). Build clean. |
| 5.9 | Verify `Assets.xcassets/AccentColor` exists | ☐ | Build setting `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor` is correct. **Anu — confirm in Xcode the `AccentColor` set exists in `Assets.xcassets` and has a colour for both Light and Dark appearances.** |
| 5.10 | Verify launch screen (storyboard or `UILaunchScreen` plist entry) | ✅ | `INFOPLIST_KEY_UILaunchScreen_Generation = YES` — Xcode auto-synthesises a default launch screen, valid for App Store. If you want a branded splash later, replace with a custom `UILaunchScreen` dict in `Custom-Info.plist`. |
| 5.11 | Cold-launch perf on real iPhone < 2s to interactive | ☐ | Anu — quick check on a physical device. |
| 5.12 | Airplane-mode smoke test — GC unauthenticated path renders cleanly | ☐ | Anu — toggle airplane mode, open every tab. Leaderboard tab should show the Sign-in / friends-error states (already swept to `AppEmptyState` in Phase 3). |
| 5.13 | Full sandbox GC testing checklist | ☐ | Anu — see `TESTFLIGHT_NOTES.md` § "Internal QA matrix" below. Fresh sandbox tester required; existing real-Apple-ID accounts have stale scores. |
| 5.14 | Draft "What to Test" tester notes | ✅ | New file at `TESTFLIGHT_NOTES.md` (repo root). Contains both the body to paste into ASC's "What to Test" field and an internal QA matrix. **Anu — review wording, then paste before tagging the build for external review.** |
| 5.15 | Capture + upload screenshots | ✅ | 7 screenshots captured in iPhone 17 Pro Max simulator (1320×2868 PNG), uploaded via `asc screenshots upload` 2026-04-26 — all 7 reached COMPLETE state. Files: home, signals, archive, cargo, shift, circuit, leaderboard. Apple bins the 6.9" screenshots under `APP_IPHONE_67` since 6.5"/6.7"/6.9" share one slot. |
| 5.16 | ASC description / keywords / support URL / privacy URL | ✅ | URLs live on GitHub Pages 2026-04-25. Metadata pushed to ASC via `asc metadata push` 2026-04-26 — name "Prisma Puzzles", new subtitle, full description, keywords, promotional text, privacy URL, support URL. `whatsNew` deliberately omitted (Apple rejects it on first v1.0 release). |
| 5.16a | (NEW) Content rights declaration in ASC | ✅ | `asc apps update --id 6762262232 --content-rights DOES_NOT_USE_THIRD_PARTY_CONTENT` ran cleanly 2026-04-26. |
| 5.16b | (NEW) Copyright field on version | ✅ | `asc versions update` ran cleanly 2026-04-26. |
| 5.16c | (NEW) App Review contact info — first/last name, email, phone | ✅ | Filled via ASC web 2026-04-26. |
| 5.16d | (NEW) App Availability (Pricing and Availability) | ✅ | Filled via ASC web 2026-04-26. |
| 5.16e | (NEW) App Privacy nutrition label / "App Privacy" section | ✅ | "App Privacy" and "Privacy Nutrition Label" are Apple's two names for the same disclosure. Filled via ASC web 2026-04-26. |
| 5.17 | Submit first TestFlight build | ✅ | Build 2 (ID `61f54bab-690b-465e-82d9-23d0f034508b`) uploaded + processed VALID + attached to External Testing group + submitted to Beta App Review on 2026-04-26 via `asc publish testflight ... --submit --confirm --wait`. Public link reserved at https://testflight.apple.com/join/fb2t4JDk — goes live once Apple approves (typically 1–24h). |

---

## Decision log

Running record of judgment calls made during the restructure — so future-Anu and future-Claude don't re-litigate them.

- **2026-04-23** — Leaderboard tab uses segmented `Rankings | Friends` inside one tab rather than two separate tabs. Rationale: both views read from the same GC dataset; users expect zero latency switching between them.
- **2026-04-23** — Segment state stored via `@SceneStorage` so it survives tab switches and app relaunches.
- **2026-04-23** — Streak leaderboard IDs stay in `GameCenterManager.Leaderboard` constants for now. UI references are removed in Phase 2. Full constant removal deferred to a separate grep-clean PR.
- **2026-04-23** — Challenge-a-friend button removed (not replaced). Generated `prisma://challenge?...` URLs that had no handler. Re-adding a working invite flow is out of scope for this slice.
- **2026-04-23** — ASC achievement art: SF Symbol + gradient rendered at 512×512 via a small Swift CLI. Can be replaced with hand-designed art post-launch without code changes.
- **2026-04-23** — Push-notification background mode stays in `Custom-Info.plist`. Notifications are planned within the next short horizon.
- **2026-04-23 (Phase 1)** — Supporting types (`LeaderboardEntry`, `LeaderboardScope`, `LeaderboardMetric`, `GamePickerChip`, `RankRow`) moved from `LeaderboardView.swift` into `LeaderboardContent.swift` rather than kept dual-declared. This made the old `LeaderboardView.swift` a true thin wrapper (just `LeaderboardView` struct + preview) and avoided duplicate-symbol errors. Same pattern applied to `GKPlayer: Identifiable` conformance — moved from `FriendsTabView.swift` into `FriendsListContent.swift`.
- **2026-04-23 (Phase 1)** — Also migrated the `GKAccessPoint.isActive` toggle for the Leaderboard tab into `LeaderboardTabView` itself instead of leaving it on the `Tab(...)` wrapper in `ContentView`. Rationale: one place to manage access-point lifecycle for that tab; keeps `ContentView` routing-only.
- **2026-04-25 (Phase 2 scope expansion)** — Pre-flight audit for task 2.6 found streak `submitScore` writes in 4 files (not just `ScoreManager`) and `FriendsService` still reading streak boards / showing a flame badge. Anu approved expanding Phase 2 to cover all of it in one pass: Cargo/Archive/Signals inline writes, `FriendsService` streak loads + helper, `FriendGameStats.currentStreak`/`streakRank` fields, `FriendTodayEntry.streak`, `FriendTodaySummary.maxStreak`, `HeadToHead` streak tiebreak, and the dependent test fixtures.
- **2026-04-25 (Phase 2)** — `StreakManager.recordDailyWin(...)` calls preserved in all four game views even though we no longer write to streak boards. Reason: the local streak count still drives `streak_3/7/30` achievements and the You-tab streak UI. Removing it would silently break those.
- **2026-04-25 (Phase 2)** — `AsyncServiceTests.submitDailyWin` rewritten to submit `signalsDailyBest` + `localMastery` rather than `signalsDailyBest` + `signalsDailyStreak`. Two-real-IDs payload preserves multi-ID submission coverage with constants that match production behaviour, instead of using a no-op streak ID for test scaffolding.
- **2026-04-25 (Phase 3 — Anu requested)** — Leaderboard tab Rankings segment restructured: text-chip game picker (`GamePickerChip`) → fixed-width icon row (`GameIconChip`, 44×44, theme-accent fill on selection). Selected game name renders as a section heading below the icons with "· today's friends" subtext for context. Rationale: removes horizontal-scroll clutter, brings the picker into visual harmony with `FriendRow`'s icon strip.
- **2026-04-25 (Phase 3 — Anu requested)** — `LeaderboardScope` enum + `Picker` removed entirely. Rankings always query `playerScope: .friendsOnly`, `timeScope: .today`. Rationale: All-Time scope semantics (`GKLeaderboard.TimeScope.allTime` returns each player's single highest-ever score across history) are confusing for a daily-puzzle app where "today's score" is the meaningful comparison; with streak boards out (Phase 2), the only sensible scope is today + friends. Trade-off: players with no GC friends will see the empty state more often. Empty-state copy updated to "None of your friends have posted today's score yet — check back later." If we ever want to expose Global today, restoring is a small change.
- **2026-04-25 (Phase 3)** — `emptyDailySection` in `ProfileView` deliberately not swept. It's an inline in-card empty (~120pt tall) and `AppEmptyState` is sized for fullscreen contexts. If uniformity becomes important later, add `Layout.inline` to `AppEmptyState` rather than retrofitting the existing card.
- **2026-04-25 (Phase 3 — Anu requested)** — Added `person.crop.circle.badge.plus` toolbar button to the Friends segment (top-trailing). Tapping calls `GKAccessPoint.shared.trigger` so the user can search, send, and accept friend requests in Apple's native GC UI. Apple owns the friend-management flow — we can only deep-link to their dashboard, not implement an in-app add-friend search. Button only shows when GC is authenticated AND friends permission is authorized (hidden on auth gate / permission states to avoid confusing pre-auth users). The "Open Game Center" CTA inside `noFriendsEmptyState` covers the same path for users with zero friends, and the persistent `GKAccessPoint` trophy at top-leading is the third entry point.
- **2026-04-25 (Phase 4 wording fix)** — `prisma.perfect_archive` localisation draft said "Identify an Archive image on your very first guess." But Archive is "Guess the historic date" per `GameType.description`, not an image puzzle. Updated to "Identify the Archive date on your very first guess." Earned-state shortened to "Got it in one" (cleaner than "Identified it in one").
- **2026-04-25 (Phase 4 ASC reality reconciliation — Anu screenshot)** — `GAME_CENTER_STATUS.md` claimed `prisma.perfect_signal`, the three streak achievements, and the three local-mastery achievements were all already configured in ASC. Anu's ASC screenshot showed the *only* achievements live are the five `first_*` (one per game). All other achievements declared in `GameCenterManager.Achievement` fire from the app and silently no-op. Phase 4 scope corrected: added `prisma.perfect_signal` to the icon generator (now 8 PNGs not 7) and to the ASC config tasks (4.6b). Streak + local-mastery achievements left for Anu's call — flagged as a separate decision in current chat thread, not auto-rolled into Phase 4. Status doc itself needs a follow-up edit to drop the false ✓ markers; logged here so we don't act on its claims again.
- **2026-04-25 (Phase 4 budget correction — Anu screenshot)** — `GAME_CENTER_STATUS.md` lists each `first_*` as 50pt; Anu's ASC has them at 20pt. Total achievement budget recalculation deferred until streak + local decision is made.
- **2026-04-25 (Phase 4 — Anu decided)** — Streak achievements (`prisma.streak_3 / 7 / 30`) removed entirely from the codebase. Streaks remain a fully in-app feature: `StreakManager` keeps recording daily wins, the You-tab streak UI continues to render, and `Badge.streak3 / 7 / 30` (in-app badges, not GC achievements) still earn through `BadgeManager`. Removed sites: `ScoreManager.reportAchievements` (3 lines + the `currentStreak` parameter), `CargoGameView` / `ArchiveGameView` / `SignalsGameView` inline achievement reports (4 lines × 3 files), the `streak3 / 7 / 30` constants in `GameCenterManager.Achievement`, the `streakIDConvention` test in `GameCenterIntegrationTests`. Streak *leaderboard ID* constants in `GameCenterManager.Leaderboard` kept (Phase 2 locked decision). Build clean (4.8s).
- **2026-04-25 (Phase 4 — Anu decided)** — Local mastery achievements (`prisma.local_25 / 50 / 100`) removed from Game Center integration, same rationale as streaks. Milestones already live in-app via `Badge.local25 / 50 / 100`, granted by `BadgeManager` based on `totalWon` thresholds. Removed sites: `ScoreManager.reportMasteryAchievements` helper + both call sites; `CargoGameView` / `ArchiveGameView` / `SignalsGameView` non-daily-win blocks (3 `reportProgressAchievement` lines × 3 files); `local25 / 50 / 100` constants in `GameCenterManager.Achievement`; `masteryIDConvention` test; `AsyncServiceTests.asyncGameCenterAchievementProgressClamping` rewired to use a placeholder string instead of a now-deleted constant. The `prisma.local.mastery` *leaderboard* itself stays — it's a real configured ASC entry that ranks total wins across all players. Build clean (4.4s).
- **2026-04-25 (Phase 4 — Anu decided)** — Track A complete: artwork + localisation uploaded for all five existing first-win achievements. Track B (the five new perfect-win ASC entries) deferred to a post-launch pass. Code already wires `gc.reportAchievement(...)` for all five `perfect_*` IDs; calls silently no-op until ASC entries exist, so this is **not a TestFlight blocker** — first-time achievement bannering for Cold Read / Dead Reckoning / Tetris Mode / No Backsies / Par Excellence simply won't fire until the ASC entries are added later. Phase 5 can proceed.
- **2026-04-25 (Phase 5 — settings audit)** — Most build settings were already correct. Only two files needed edits: `INFOPLIST_KEY_LSApplicationCategoryType` changed from `strategy-games` to `puzzle-games` (ASC categorisation; Prisma is decisively a puzzle app), and `ITSAppUsesNonExemptEncryption = false` added to `Custom-Info.plist` (skips the export-compliance dialog on every TestFlight submission — the app uses no custom crypto, only Apple-provided HTTPS). Build clean (4.2s). Other settings already in place: deployment target 18.0, `CFBundleDisplayName = Prisma`, `MARKETING_VERSION = 1.0`, auto-generated launch screen, friends-permission usage description, asset-catalog AppIcon + AccentColor names. Bundle ID `AG.Prisma` set; Anu must confirm match against ASC App Information record.
- **2026-04-25 (Phase 5 — icon alpha fix)** — First ASC upload failed validation with error 90717: "Invalid large app icon. The large app icon in the asset catalog can't be transparent or contain an alpha channel." All three 1024×1024 PNGs (light / dark / tinted) were RGBA with actual transparent pixels at the rounded corners. Light + dark variants flattened to opaque RGB; matte colour for each was sampled by walking inward from each of the four corners along the diagonal until we hit a fully-opaque pixel, then averaging the four samples — preserves the icon's intended look at the rounded edges with no halo. Tinted variant left RGBA because iOS 18's tinted icon mode treats the alpha as a template mask. Originals preserved as `*.alpha-backup` files in the appiconset dir (inert — Xcode reads `Contents.json` to find assets, ignores other files). Build number bumped 1 → 2 in the same pass because TestFlight may have registered build 1 even though validation failed.

---

## Open questions — still unblocked

*(None currently — all open questions from the planning round are answered. Add here as new ones surface.)*
