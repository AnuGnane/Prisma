# Prisma Puzzles — Execution Plan

Drafted 2026-05-05 from `ROADMAP.md`. This is the agent-executable phase plan — each task has a clear scope, owner, dependencies, and acceptance criteria. Phase order respects dependencies and mirrors the build cadence (each phase typically ends with a TestFlight push).

**Status legend:** ☐ not started · ◐ in progress · ✅ done · ⚠️ blocked · ⏸ paused · ✂️ dropped

**Owner legend:**
- `[AGENT]` — Cowork agent can execute autonomously with the existing toolchain
- `[ANU]` — requires your hands (web ASC, real device, design judgment)
- `[AGENT+REVIEW]` — agent drafts/runs, you review before commit/push

---

## Decisions (answered 2026-05-06)

| # | Question | Answer | Implication |
|---|---|---|---|
| Q1 | Build 4 scope | **Wider** — bundle Daily Sweep + Share Card into build 4 | F.3 + G.1 promoted to Phase B |
| Q2 | App Store launch criteria | Ship as soon as Apple approves | Phase D becomes opportunistic, not gating |
| Q3 | Difficulty selector | **Drop** | J.2 ✂️ removed |
| Q4 | Hints system | **Drop** | J.1 ✂️ removed |
| Q5 | Localisation | **Defer** — keep en-GB for v1.1, expand later | Phase H moves to v1.2+ horizon |
| Q6 | Tip jar / Prisma Pro | **v2.0** | Stays in Phase L |
| Q7 | iPad re-enablement | **v2.0** | Stays in Phase L |
| Q8 | Test coverage bar | **Pragmatic** | Tests for persistence + game logic; snapshot tests for new views; none for trivial UI |
| Q9 | Code review style | **Per-phase batch** | Agent completes whole phase, builds, surfaces diff for your review before next phase |
| Q10 | MetricKit crash reporting | **Yes, in v1.0 polish** | Stays as B.3 |

---

## Phase A — Quick Wins (build 4 fodder)

**Goal:** clean off every item in the Quick Wins section of `ROADMAP.md`. Each one is a 1–15 minute change; bundling them keeps the diff coherent and the build cadence fast.

**Owner:** mostly `[AGENT]`. ASC items are `[ANU]`.

**Estimated effort:** 1–2 hours of agent time, 15 min of your time.

**Acceptance criteria:**
- All five "Quick Wins" code items merged
- ASC perfect-win achievements live
- Build still compiles cleanly
- No new test failures

| # | Task | Owner | Files touched | Time | Status |
|---|---|---|---|---|---|
| A.1 | StatCard "/ 100" → uses `GameType.localLevelCount` (150 today, future-proof) | `[AGENT]` | `Features/Profile/ProfileView.swift` | 5 min | ✅ |
| A.2 | Badge descriptions: 100 → 150 across `Badge.signalsMaster / archiveMaster / cargoMaster / shiftMaster` (and Circuit per A.3) | `[AGENT]` | `Core/Models/Badge.swift` | 5 min | ✅ |
| A.3 | Add `circuitMaster` enum case + title + description + icon + accent + grant logic in `BadgeManager`. **Bonus:** caught 3 latent BadgeManager bugs while in the file — `streakGames` was missing `"circuit"` (excluding it from the max-streak calculation), per-game mastery threshold was hardcoded to 100 instead of `game.localLevelCount`, and the mastery loop didn't include Circuit at all. All three fixed. | `[AGENT]` | `Core/Models/Badge.swift`, `Core/Services/BadgeManager.swift` | 10 min | ✅ |
| A.4 | NotificationManager body: include Circuit in the games list | `[AGENT]` | `Core/Services/NotificationManager.swift` | 1 min | ✅ |
| A.5 | Gate `[FriendsService]` print statements behind `#if DEBUG` | `[AGENT]` | `Core/Services/FriendsService.swift` | 10 min | ✅ |
| A.6 | Configure 5 perfect-win achievements in ASC (Cold Read / Dead Reckoning / Tetris Mode / No Backsies / Par Excellence). PNGs already exist; localisation in `LEADERBOARD_RESTRUCTURE_TASKS.md` | `[ANU]` | ASC web | 15 min | ☐ |

**Phase exit:** clean build + manual smoke test of badges grid (verify `circuitMaster` renders). **Status: code complete 2026-05-06, build clean (7.4s), awaiting Anu review + A.6 ASC config before Phase B starts.**

---

## Phase B — v1.0 Polish + selected v1.1 features (build 4 fodder)

**Goal:** finish every item in the `## v1.0 Polish` section of the roadmap, **plus** the two highest-impact v1.1 features (Daily Sweep + Share Card) per Q1 = wider build 4.

**Owner:** `[AGENT]` for code, `[ANU]` for visual judgment calls + per-phase batch review at the end.

**Estimated effort:** ~1.5 days of agent time.

**Dependency:** Phase A completes first.

| # | Task | Owner | Files touched | Time | Status |
|---|---|---|---|---|---|
| B.1 | DailyResultRow: per-game metric formatting. Cargo/Shift/Circuit → time format ("42s", "1:45"); Signals/Archive → "X guesses". Reuse the same metric helper used on the leaderboard rows | `[AGENT]` | `Features/Profile/ProfileView.swift` (or wherever DailyResultRow lives), shared metric formatter | 15 min | ☐ |
| B.2 | Audit `try?` silent failures across all GameKit calls. Replace with explicit error logging (gated behind `#if DEBUG`) so failures aren't silently lost | `[AGENT]` | grep `try?` → `Core/Services/*.swift`, game-view extensions | 30 min | ☐ |
| B.3 | Add MetricKit crash + hang reporting (Q10 = yes). On-device only, no PII leaves the device, no privacy nutrition label change required | `[AGENT]` | new `Core/Services/MetricsManager.swift`, `PrismaApp.swift` registers it | 30 min | ☐ |
| B.4 | Harden Circuit tests — replace placeholder assertions with strict checks. Carry-over task #40 from `app_summary.md` | `[AGENT]` | `PrismaTests/CircuitGameTests.swift` and friends | 1 hr | ☐ |
| B.5 | **Daily Sweep celebration** (promoted from F.3). When player completes all 5 dailies for a given day, show a celebratory overlay with aggregate stats (total time, perfect-clear count). Trigger on the 5th daily-completion of the day. Per Q8 pragmatic test bar — add unit test for the "is today's sweep complete" predicate, snapshot test for the overlay view | `[AGENT]` | new `Features/Profile/DailySweepView.swift`, completion-detection hook in each daily flow, `PrismaTests/DailySweepTests.swift` | 4 hrs | ☐ |
| B.6 | **Share card** (promoted from G.1). Render today's daily results across all 5 games as a single shareable image using `ImageRenderer`. Wordle-style summary with Prisma's per-game accent palette. Hook into existing `ShareLink` paths so it integrates with the daily completion flow. Per Q8 — snapshot test for the rendered card | `[AGENT]` | new `Features/Profile/ShareCardView.swift` + `ShareCardRenderer.swift`, `PrismaTests/ShareCardTests.swift` | 4 hrs | ☐ |
| B.7 | Build cleanly + run tests | `[AGENT]` | n/a | 5 min | ☐ |
| B.8 | Per-phase review surface — produce a one-page summary of all changes in B for Anu's review before Phase C | `[AGENT+REVIEW]` | n/a | 5 min | ☐ |

**Phase exit:** clean build, all tests pass, Anu signs off on the change summary.

---

## Phase C — Build 4 ship

**Goal:** Push build 4 to TestFlight, update tester notes, monitor for issues.

**Dependency:** Phase A + B complete.

| # | Task | Owner | Time | Status |
|---|---|---|---|---|
| C.1 | Bump `CURRENT_PROJECT_VERSION` 3 → 4 | `[AGENT]` | 1 min | ☐ |
| C.2 | Update `TESTFLIGHT_NOTES.md` build number + add a "What's new in build 4" subsection summarising A + B changes | `[AGENT]` | 10 min | ☐ |
| C.3 | Archive in Xcode → upload to ASC | `[ANU]` | 15 min | ☐ |
| C.4 | Confirm build 4 processes `VALID` via `asc builds list --app 6762262232` | `[AGENT]` | 5 min | ☐ |
| C.5 | Distribute build 4 to External Testing group; submit to Beta App Review | `[AGENT]` | 5 min | ☐ |
| C.6 | Paste "What to Test" body into ASC for build 4 | `[AGENT+REVIEW]` | 5 min | ☐ |
| C.7 | Wait for Beta App Review approval (1–24h) | `[ANU]` | passive | ☐ |
| C.8 | Confirm public TestFlight link still works after build 4 swap | `[ANU]` | 2 min | ☐ |

**Phase exit:** Build 4 live for external TestFlight testers.

---

## Phase D — TestFlight feedback collection

**Goal:** Anu drives this — the agent can't do device-side testing or recruitment.

**Dependency:** Phase C complete + at least 3 external testers installed.

**Estimated effort:** 1–2 weeks of passive collection.

| # | Task | Owner |
|---|---|---|
| D.1 | Recruit 5–10 external testers via TestFlight public link | `[ANU]` |
| D.2 | Set up a feedback-collection process (Discord, email thread, Apple's TestFlight feedback API) | `[ANU]` |
| D.3 | Walk own iPhone 11 + iPhone Air through the QA matrix in `TESTFLIGHT_NOTES.md`, especially: cold-launch, airplane mode, sandbox GC, dark mode + dynamic type | `[ANU]` |
| D.4 | Document each piece of feedback with category (bug / feature request / nit) | `[AGENT+REVIEW]` could help triage |

**Phase exit:** A consolidated feedback document with prioritised follow-ups.

---

## Phase E — v1.1 Foundations (schema + infrastructure)

**Goal:** Set up the schema and infrastructure changes that v1.1 features depend on. Avoids midstream migrations later.

**Dependency:** Phase D feedback shapes the priorities, but most of these foundations are needed regardless.

**Estimated effort:** 1–2 days.

| # | Task | Owner | Files | Time | Status |
|---|---|---|---|---|---|
| E.1 | SwiftData schema audit: confirm `LevelProgress` already stores `score`, `guessesUsed`, `durationSeconds`, `playedDate`. Add `personalBest*` fields if needed for the v1.1 PB feature | `[AGENT]` | `Core/Models/LevelProgress.swift` | 30 min | ☐ |
| E.2 | Define a `MigrationPlan` per Apple's Versioned `SchemaMigrationPlan` so future schema changes can be additive | `[AGENT]` | `Core/Models/MigrationPlan.swift` (new) | 1 hr | ☐ |
| E.3 | Push notification entitlement: enable APNs in capabilities, add `aps-environment` to entitlements, register for remote notifications in `PrismaApp.swift` | `[AGENT+REVIEW]` | `Prisma.entitlements`, `PrismaApp.swift` | 30 min | ☐ |
| E.4 | Privacy nutrition label revisit: APNs registration changes the answer to "Do you collect data?" — re-fill with new "Identifiers (Device ID)" → "App Functionality" if push is enabled | `[ANU]` | ASC web | 5 min | ☐ |

**Phase exit:** Schema, entitlements, and privacy disclosures all aligned for v1.1 push features.

---

## Phase F — v1.1 Stats & Analytics

**Goal:** ship the remaining v1.1 enhanced-stats features (Daily Sweep already shipped in build 4 per Q1).

**Dependency:** Phase E complete.

**Estimated effort:** 1.5 days (down from 2 since F.3 moved to Phase B).

| # | Task | Owner | Files | Time | Status |
|---|---|---|---|---|---|
| F.1 | Personal-best tracking — surface PB on each game's detail screen. Read from `LevelProgress` (best score / fewest guesses / fastest time per level) | `[AGENT]` | `Features/<game>/Views/GameDetailView` | 4 hrs | ☐ |
| F.2 | Solve-time distribution view per game: small histogram or sparkline of last 20 daily solves. Reuses existing `GameResult` data | `[AGENT]` | `Features/Profile/SolveTimeStatsView.swift` | 4 hrs | ☐ |
| F.3 | ~~Daily Sweep celebration~~ | — | — | — | ✅ Shipped in Phase B (B.5) |
| F.4 | Weekly recap notification: Sunday evening local time, body summarises streak / PBs / levels completed that week | `[AGENT]` | `NotificationManager.swift` (new schedule), `Core/Services/WeeklyRecapBuilder.swift` (new) | 2 hrs | ☐ |
| F.5 | Pragmatic tests (Q8) — unit tests for `WeeklyRecapBuilder`'s aggregation, persistence test for PB write-on-completion | `[AGENT]` | `PrismaTests/` | 1 hr | ☐ |

**Phase exit:** clean build, tests pass, manual smoke test of all features.

---

## Phase G — v1.1 Social

**Goal:** ship the remaining social features (Share Card already shipped in build 4 per Q1).

**Dependency:** Phase F complete (or parallel — Phase G doesn't depend on Phase F).

**Estimated effort:** 1.5–2 days (down from 2–3 since G.1 moved to Phase B).

| # | Task | Owner | Files | Time | Status |
|---|---|---|---|---|---|
| G.1 | ~~Share card~~ | — | — | — | ✅ Shipped in Phase B (B.6) |
| G.2 | "Today" segment on `FriendProfileView` — adds a third comparison strip alongside the existing all-time H2H, scoped to today's daily | `[AGENT]` | `Features/Friends/FriendProfileView.swift`, `FriendsService.swift` | 4 hrs | ☐ |
| G.3 | Friend-beat-your-score nudge: subtle banner on the Games tab when a friend has bested your daily score. Drives re-engagement without push spam | `[AGENT]` | `Features/Profile/HomeView.swift`, daily score-comparison helper | 3 hrs | ☐ |
| G.4 | Push notification: when a friend posts a score on a daily you've played, optional notification. **Gated behind a settings toggle so users can opt out** | `[AGENT]` | `NotificationManager.swift`, settings UI | 4 hrs | ☐ |
| G.5 | Pragmatic tests (Q8) — head-to-head logic for the today comparison, notification-permission state machine | `[AGENT]` | `PrismaTests/` | 1.5 hrs | ☐ |

**Phase exit:** clean build, tests pass.

---

## Phase H — Localisation (deferred to v1.2+)

**Status:** ⏸ Deferred per Q5 — keep en-GB only for v1.1, expand later when there's a clear demand signal.

**When to revisit:** if TestFlight feedback or App Store Analytics shows meaningful traffic from non-English-locale devices, prioritise the most-represented locale first. The string-extraction work (H.1, H.2) is a prerequisite to anything here, so when you're ready, that's the first task to schedule.

| # | Task | Owner | Time | Status |
|---|---|---|---|---|
| H.1 | Audit string-literal usage in views; migrate to `String(localized:)` where missing | `[AGENT]` | 4 hrs | ⏸ |
| H.2 | Set up `Localizable.xcstrings` with all extracted keys | `[AGENT]` | 2 hrs | ⏸ |
| H.3 | Localise to first locale | `[AGENT+REVIEW]` | 3 hrs | ⏸ |
| H.4 | Localise to remaining locales | `[AGENT+REVIEW]` | varies | ⏸ |
| H.5 | RTL pass if Arabic / Hebrew added | `[AGENT]` | 2 hrs | ⏸ |
| H.6 | Update ASC metadata per locale | `[AGENT]` | 3 hrs / locale | ⏸ |

---

## Phase I — v1.1 Accessibility

**Goal:** Ship the accessibility roadmap items. VoiceOver audit is the heaviest task.

**Dependency:** None (can run in parallel with other phases).

**Estimated effort:** 1–2 days.

| # | Task | Owner | Time | Status |
|---|---|---|---|---|
| I.1 | VoiceOver audit: every game board navigable. Custom accessibility actions for Circuit path-drawing and Cargo piece placement | `[AGENT+REVIEW]` | 6 hrs | ☐ |
| I.2 | Dynamic Type stress test at XXXL and AX sizes. Fix clipping in `StatCard`, `StreakPill`, leaderboard rows | `[AGENT]` | 2 hrs | ☐ |
| I.3 | Colourblind mode (Q3-related): alternative palette for Signals' colour-coded feedback and Circuit's path highlighting. Add a Settings toggle | `[AGENT]` | 4 hrs | ☐ |
| I.4 | Reduce-motion check across all games (existing flag is honoured; verify) | `[AGENT]` | 1 hr | ☐ |

**Phase exit:** Accessibility audit clean.

---

## Phase J — v1.1 Gameplay refinements

**Goal:** ship the gameplay refinements that survived the Q3/Q4 decisions.

**Dependency:** None.

**Estimated effort:** half a day.

| # | Task | Owner | Files | Time | Status |
|---|---|---|---|---|---|
| J.1 | ~~Hints system~~ | — | — | — | ✂️ Dropped per Q4 — undermines puzzle purity, conflicts with brand ethos |
| J.2 | ~~Difficulty selector~~ | — | — | — | ✂️ Dropped per Q3 — breaks the shared-daily social premise |
| J.3 | Undo history visualisation in Circuit — show a ghost trail of the last few moves so the player can see their exploration path | `[AGENT]` | `Features/Circuit/Views/CircuitGameView.swift`, `CircuitGameViewModel.swift` | 2 hrs | ☐ |
| J.4 | Sound + haptic per-game settings — add per-game granularity so players can have haptics in Circuit but not Archive (etc.) | `[AGENT]` | `Features/Profile/SettingsView.swift`, `Core/Services/AppSettings.swift`, sound/haptic call sites | 2 hrs | ☐ |
| J.5 | Pragmatic tests (Q8) — only the AppSettings persistence; undo-trail is purely visual | `[AGENT]` | `PrismaTests/` | 30 min | ☐ |

**Phase exit:** clean build.

---

## Phase K — v1.1 release prep + ship

**Goal:** push v1.1 to App Store.

**Dependency:** Phases E–J complete (which actually ship in v1.1).

| # | Task | Owner | Time | Status |
|---|---|---|---|---|
| K.1 | Update `MARKETING_VERSION` 1.0 → 1.1 | `[AGENT]` | 1 min | ☐ |
| K.2 | Set `whatsNew` field for v1.1 (now allowed, since not first release) — summarise notable additions | `[AGENT+REVIEW]` | 10 min | ☐ |
| K.3 | Capture 2–3 new screenshots showing v1.1 features | `[ANU]` | 30 min | ☐ |
| K.4 | Run `asc metadata push --version 1.1` | `[AGENT]` | 5 min | ☐ |
| K.5 | Archive + upload via Xcode | `[ANU]` | 15 min | ☐ |
| K.6 | Distribute to TestFlight, then submit for App Store review | `[AGENT]` | 10 min | ☐ |

**Phase exit:** v1.1 in Apple's App Store review queue.

---

## Phase L — v2.0 Vision (deferred)

**Each item below is a multi-week project. They're listed for completeness but should be re-prioritised after v1.1 is in users' hands.**

- **Tip jar / Prisma Pro** (StoreKit, restore purchases, receipt validation) — 2–3 days
- **iPad re-enablement** (adaptive layouts across all 5 games + Cargo / Circuit benefit most) — 1 week
- **watchOS complication + widget** — 1 week
- **App Intents / Shortcuts / Live Activities** — 3 days each
- **New game modes (Spectrum, Echo, Grid, Vault)** — 2–4 weeks per game, design phase first
- **Server-side daily generation** — major architectural change, 2+ weeks
- **CloudKit dashboard analytics** — internal-only tool, ~1 week

---

## Cross-cutting concerns

These aren't phase-bound but apply throughout:

1. **Tracker hygiene.** Keep `LEADERBOARD_RESTRUCTURE_TASKS.md` and this `EXECUTION_PLAN.md` in sync. After each task: status flip + one-line note. Don't update retroactively.

2. **Build cadence.** Push a TestFlight build at the end of each "ship" phase (C, K). Don't bundle multiple phases into one release — keeps regression isolation tight.

3. **Reviews and rejections.** Every App Store submission risks a Guideline 2.x rejection. Keep the response template in `APP_REVIEW_RESPONSE.md` updated after each successful submission so the next reply is faster.

4. **Decision log.** Anything that changes the product direction goes into `ROADMAP.md` § Decision Log. Implementation decisions go into the relevant tracker file's decision log.

5. **`.gitignore` discipline.** Anything credential-shaped (`.p8`, `.env`, `.pem`) stays out of the repo permanently. The current `.gitignore` covers these — don't loosen it.

6. **Test coverage policy** — pending Q8, but my recommendation is the **Pragmatic** option: tests for persistence + game logic, snapshot tests for new views, none for trivial UI changes.

---

## Things deliberately not on this plan

- **Marketing / launch announcement** — out of agent scope; you handle product launch storytelling.
- **App Store rating campaigns** — Apple's policies make these touchy; default behaviour (one rating prompt per build) is fine.
- **External analytics SDKs** (Mixpanel, Amplitude, etc.) — we deliberately avoided these in the privacy nutrition label. Don't add them without revisiting the privacy disclosure.
- **In-app surveys** — same reason.
