# Prisma Puzzles — App Summary

Last updated: 2026-05-04

This document is the canonical snapshot of where Prisma Puzzles stands right now. It supersedes the 2026-04-20 version, which was scoped to Circuit's stabilisation work; the app has since gone through a full level-catalog expansion, a leaderboard restructure, and a TestFlight + App Store submission.

---

## 1. Headline status

Prisma Puzzles v1.0 (build 3) has been submitted to the App Store. As of 2026-05-04:

- Build 3 is uploaded to App Store Connect, processed `VALID`, attached to the External Testing TestFlight group, and submitted for Beta App Review.
- The App Store review for v1.0 came back with a Guideline 2.1 ("Information Needed") request — a standard first-submission paperwork ask, not a code rejection. A response with a physical-device screen recording is being prepared (`APP_REVIEW_RESPONSE.md` at the repo root).
- Public TestFlight invite link is reserved at `https://testflight.apple.com/join/fb2t4JDk` and goes live the moment Apple approves Beta App Review.

The codebase, metadata, and submission infrastructure are all in place. The remaining work is reviewer-driven: respond, wait, ship.

## 2. Product overview

Prisma Puzzles is a single-player iOS puzzle app combining five distinct daily challenges plus a 150-level local archive per game. No accounts, no ads, no in-app purchases — Game Center handles social features, iCloud handles optional progress sync.

The five games each test a different cognitive skill:

| Game    | What it is | Daily metric |
|---------|------------|--------------|
| Signals | Crack a four-digit code in as few guesses as possible | Guess count (lower = better) |
| Archive | Identify the year of a historic photograph | Guess count |
| Cargo   | Tile a grid with irregular pieces | Elapsed seconds; perfect = 100% fill |
| Shift   | Slide rows and columns of a letter grid to reveal target words | Move count |
| Circuit | Route signals through logic gates to their targets | Elapsed seconds; perfect = at or under par |

A fresh puzzle drops every midnight local time, identical for every player worldwide, so users can compare scores against their Game Center friends.

## 3. Tech stack

- Swift 6 / SwiftUI / SwiftData / Observation
- GameKit (Game Center)
- NSPersistentCloudKitContainer (iCloud sync, optional)
- iOS 18.0+
- TARGETED_DEVICE_FAMILY = "1" (iPhone-only; iPad support intentionally dropped during Phase 5)
- All app code is first-party Apple frameworks. No third-party SDKs, analytics, or trackers.

Tooling outside the app binary:

- `asc` CLI ([rorkai/App-Store-Connect-CLI](https://github.com/rorkai/App-Store-Connect-CLI)) for ASC automation
- GitHub Pages for hosting the privacy policy and support page (`https://anugnane.github.io/prisma-pages/`)
- A small Swift script at `tools/gen_achievement_icons.swift` that renders 10 achievement PNGs at 512×512 with per-game gradient backdrops + SF Symbols

## 4. Game catalogue

All five games shipped with **150-level local archives**, expanded from earlier sizes during the level_expansion_plan work (completed 2026-04-21):

| Game | Local levels | Generation source | Notes |
|------|-------------|-------------------|-------|
| Signals | 150 | Procedural via deterministic seed | Phase 1 of expansion plan |
| Archive | 150 | Curated facts JSON | Phase 1 (fact backfill) |
| Cargo | 150 | Curated polyomino layouts | Phase 2 (bulk generation) |
| Shift | 150 | New generator | Phase 3 |
| Circuit | 150 | End-state-first Hamiltonian generator + curated extras | Phase 4 with rebalance + renumber |

Every Cargo level has a canonical 100% tiling stored inline in `cargo_puzzles.json` (a `solution` field per piece), produced by `scratch/solve_cargo.py` via exact-cover backtracking. This was added in 2026-04-21 to fix a bug where "Show Solution" always rendered "Partial Fill" for JSON-loaded levels — see commit history / decision log in `LEADERBOARD_RESTRUCTURE_TASKS.md` for context.

All 150 Circuit levels have canonical Hamiltonian-path solutions, validated by `scratch/validate_catalog.py`. Difficulty is renumbered into a natural curve: L1–25 are 5×5 with 0–1 gates, L26–50 introduce the gate mix, L51–75 step to 6×6, L76–100 6×6 multi, L101–125 6×6/7×7 heavy, L126–150 all 7×7 expert.

## 5. Core systems

### Persistence
- `GameResult` (SwiftData @Model) — per-session record for both daily and local plays
- `LevelProgress` (SwiftData @Model) — per-level completion state; granular won/best-score/duration tracking
- `PersistenceManager` — query helpers; CloudKit sync set to `.automatic`

### Progress and profile
- `StreakManager` records daily wins to local storage and drives the You-tab streak counter
- `BadgeManager` grants in-app badges for streak/local-mastery/perfect-clear milestones
- `Badge.swift` declares 12 badges across first-win, streak, local-mastery, per-game-master, performance, and speed categories

### Game Center
- 6 leaderboards live in App Store Connect (one `*.daily.best` per game + `prisma.local.mastery`)
- 5 first-win achievements live in App Store Connect (First Signal / Archive / Cargo / Shift / Circuit)
- Streak leaderboards intentionally absent — locked decision in Phase 2
- Streak achievements intentionally absent — locked decision in Phase 4 (streaks live entirely in-app via `Badge.streak3 / 7 / 30`)
- Local mastery achievements intentionally absent — same rationale (`Badge.local25 / 50 / 100`)
- 5 perfect-win achievements (Cold Read, Dead Reckoning, Tetris Mode, No Backsies, Par Excellence) are wired in code but their ASC entries are postponed for a post-launch pass; calls silently no-op until the entries land

### UX foundations
- Reduced-motion-aware animations across all games
- `Core/UI/AppEmptyState.swift` — wraps `ContentUnavailableView` with `.neutral` / `.error` styles + optional retry; used across Leaderboard, Friends, FriendProfile, and Circuit's solution view
- Light/dark theme support via `AppTheme`
- Dynamic Type support throughout

### Friends + Leaderboards (post-restructure)
The Friends and Leaderboards features were merged into a single tab during the leaderboard restructure (Phase 1, 2026-04-23). The tab is now called **Leaderboard** with a `Rankings | Friends` segmented picker, segment state persisted via `@SceneStorage`. The Rankings segment uses a compact icon-row game picker (5 chips, no horizontal scroll) and is hardcoded to `today + friendsOnly` — Apple's `.allTime` semantics were confusing for a daily-puzzle game and have been removed.

A `+` toolbar button on the Friends segment opens the native Game Center dashboard (Apple owns the friend-management flow; we deep-link to it).

`FriendsService` is the `@Observable @MainActor` singleton owning the `loadFriendsAuthorizationStatus` state machine, friend-list cache, and batched today-summary queries. It only reads from `*.daily.best` boards now (streak reads were removed in Phase 2).

## 6. App Store Connect status (2026-05-04)

| Field | Value |
|---|---|
| ASC App ID | `6762262232` |
| Bundle ID | `AG.Prisma` |
| App Store-facing name | Prisma Puzzles |
| Internal reference name | Prisma Brain Games |
| Locale | en-GB |
| Marketing version | 1.0 |
| Build number | 3 |
| Build state | `VALID`, attached to External Testing group |
| Beta App Review | Submitted |
| App Store Review | Submitted; awaiting response to Guideline 2.1 paperwork query |

Metadata pushed via `asc metadata push`:

- Subtitle: "Five daily puzzles, one app."
- Description: ~1700 chars covering all five games + archives + Game Center
- Keywords: 94 chars (logic, word, mastermind, deduction, brain teaser, code, grid, connect, strategy, routing, minimal, ritual)
- Promotional text: 156 chars
- Privacy Policy URL: https://anugnane.github.io/prisma-pages/privacy.html
- Support URL: https://anugnane.github.io/prisma-pages/support.html
- Copyright: © 2026 Aniruth Gnaneswaran
- Content rights: DOES_NOT_USE_THIRD_PARTY_CONTENT
- App Privacy section: published, no data collected by the developer
- Pricing: free, all territories
- Category: Games > Puzzle

Seven screenshots uploaded to the iPhone 6.5/6.7/6.9 shared slot (`APP_IPHONE_67`): home, signals, archive, cargo, shift, circuit, leaderboard. iPhone 17 Pro Max simulator-captured at 1320×2868. iPad and Apple Watch screenshots not required (TARGETED_DEVICE_FAMILY = "1", no WatchKit target).

## 7. Build settings (Phase 5 changes)

The following project settings were aligned during Phase 5 of the leaderboard restructure / TestFlight readiness work:

- `IPHONEOS_DEPLOYMENT_TARGET = 18.0` (Debug + Release)
- `INFOPLIST_KEY_CFBundleDisplayName = Prisma` (home screen name kept short; App Store name is the longer "Prisma Puzzles")
- `INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.puzzle-games`
- `INFOPLIST_KEY_UILaunchScreen_Generation = YES` (Xcode auto-synthesises the launch screen)
- `Custom-Info.plist` — added `ITSAppUsesNonExemptEncryption = false` to skip the export-compliance dialog on every TestFlight submission
- App icons (light + dark variants) flattened to opaque RGB after the first ASC upload failed validation with error 90717 (alpha channel on the marketing icon). Tinted variant kept its alpha channel intentionally — iOS 18 tinted-mode icons are template masks
- `TARGETED_DEVICE_FAMILY = "1"` (iPhone only)
- `CURRENT_PROJECT_VERSION` bumped to 3 after Apple required a non-iPad rebuild

## 8. Known constraints

1. **5 perfect-win achievements pending ASC config** (Cold Read, Dead Reckoning, Tetris Mode, No Backsies, Par Excellence). All wired in code, all PNGs and localisation strings drafted in `LEADERBOARD_RESTRUCTURE_TASKS.md`. Achievements will silently fire to no effect until the ASC entries are added — adding them is non-blocking and can happen post-launch.
2. **App Store v1.0 review is in a paperwork loop** — Guideline 2.1 ("Information Needed"). Response drafted in `APP_REVIEW_RESPONSE.md`; needs a 2–4 minute physical-device screen recording attached.
3. **Circuit tests still contain placeholder cases** that should be replaced with strict assertions (carry-over from earlier Circuit work). Non-blocking; tracked as task #40.
4. **Localisation is en-GB only** for v1.0. Additional locales planned post-launch.
5. **No external testers signed up yet** — TestFlight public link will go live once Beta App Review approves; recruitment hasn't started.

## 9. Documentation map

Live planning and decision documents in the repo root:

| File | Purpose |
|---|---|
| `LEADERBOARD_RESTRUCTURE_PLAN.md` | Locked-in decisions and phased delivery plan for the entire Friends/Leaderboards/TestFlight initiative |
| `LEADERBOARD_RESTRUCTURE_TASKS.md` | Live task tracker with status per task + decision log |
| `ASC_SUBMISSION.md` | All App Store Connect copy fields and submission checklist |
| `TESTFLIGHT_NOTES.md` | "What to Test" body for TestFlight + internal QA matrix |
| `APP_REVIEW_RESPONSE.md` | Guideline 2.1 reply text + screen-recording instructions |
| `game_center_plan.md` | Original (now superseded) Game Center / Friends design — historical context |
| `level_expansion_plan.md` | Plan for the 100→150 catalog expansion across all five games |
| `prisma_handoff_current.md` | Older project handoff doc; sections may be stale |

Auto-memory snapshots from earlier work:

| File | Topic |
|---|---|
| `.auto-memory/project_circuit_coverage.md` | Circuit catalog coverage state at 150 levels |
| `.auto-memory/project_cargo_solutions.md` | Cargo canonical-solution work + Show Solution fix |

## 10. Near-term roadmap

In likely execution order:

1. Reply to App Store reviewer with screen recording (`APP_REVIEW_RESPONSE.md`) — unblocks v1.0 launch.
2. Wait for Beta App Review approval — opens external TestFlight to the public link.
3. Walk the Internal QA matrix on iPhone 11 + iPhone Air (closes tasks 3.8, 4.11, 5.11, 5.12, 5.13).
4. Gather TestFlight feedback for one or two cycles before pushing build 4.
5. Configure the 5 perfect-win achievements in ASC (15 minutes; code is already wired; PNGs already generated).
6. Harden Circuit tests (task #40) — replace placeholder assertions.
7. Add additional locales after launch.

Stretch / opportunistic:

- Audio + haptic polish and per-game settings.
- Daily-reminder notifications for retention.
- A user-controlled clean iCloud-sync reset flow.
- Scale a game's archive 150→200 if playtest data shows it's being burned through (task #41).
