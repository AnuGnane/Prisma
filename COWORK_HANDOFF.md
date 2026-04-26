# Cowork Handoff — Prisma Leaderboard Restructure & TestFlight Push

**For:** A new Cowork session picking up this work
**Written:** 2026-04-23
**Predecessor:** Web claude.ai conversation (Opus 4.7), now closed

---

## TL;DR for the next session

You're picking up a multi-phase iOS engineering project. The previous session **completed all the code changes for Phase 1** of a 5-phase plan but **could not verify the build** (Xcode MCP build tool was timing out). Anu's first action is a local `cmd-B` to confirm Phase 1 compiles. Phase 2 starts once that's green.

**Read these four files in order before doing anything else:**

1. `/Users/anugnana/Library/Projects/Prisma/Prisma/LEADERBOARD_RESTRUCTURE_PLAN.md` — strategy, scope, locked decisions
2. `/Users/anugnana/Library/Projects/Prisma/Prisma/LEADERBOARD_RESTRUCTURE_TASKS.md` — live task tracker (status of every step)
3. `/Users/anugnana/Library/Projects/Prisma/game_center_plan.md` — original Game Center / Friends design doc
4. `/Users/anugnana/Library/Projects/Prisma/GAME_CENTER_STATUS.md` — what's wired up in Game Center today
5. `/Users/anugnana/Library/Projects/Prisma/app_summary.md` — overall app state for context

Then summarize back to Anu what state we're in and what the next task is. Do not start any code work until that summary is confirmed.

---

## Project context

**App:** Prisma — iOS puzzle app, Swift 6 / SwiftUI / SwiftData / GameKit, iOS 18.0+
**Repo root:** `/Users/anugnana/Library/Projects/Prisma/`
**Xcode project:** `/Users/anugnana/Library/Projects/Prisma/Prisma/Prisma.xcodeproj`
**Owner:** Anu (Anu Gnana)

**Current goal:** restructure the social/leaderboard surface, polish the rough edges, and submit a TestFlight build.

The five games shipped: Signals, Archive, Cargo, Shift, Circuit. All have working daily puzzles, local archives, and Game Center hooks (with known gaps documented in `GAME_CENTER_STATUS.md`).

---

## The 5-phase plan (full detail in `LEADERBOARD_RESTRUCTURE_PLAN.md`)

| Phase | Description | Status |
|---|---|---|
| 1 | Restructure: rename "Friends" tab to "Leaderboard" with a segmented `Rankings` / `Friends` toggle inside | ✅ Code complete · ⚠️ Build unverified |
| 2 | Strip Streak metric picker from `LeaderboardContent`; remove dead `challengeButton`; delete Phase 1 wrapper files | ☐ Not started |
| 3 | Empty-state & error-state polish — introduce `AppEmptyState` helper, sweep callers | ☐ Not started |
| 4 | Configure 7 missing ASC achievements with SF-Symbol-based 512×512 images and EN localization | ☐ Not started |
| 5 | TestFlight readiness — version bump, Info.plist audit, asset audit, sandbox QA, ASC submission | ☐ Not started |

---

## Locked-in decisions (don't re-litigate these)

These were debated and answered in the previous session:

- **Tab rename:** `Friends` → `Leaderboard`, icon `trophy.fill`.
- **Layout:** Segmented `Rankings | Friends` inside the one tab, not two separate tabs.
- **Segment memory:** `@SceneStorage("leaderboardSegment")` — survives tab switches and relaunches.
- **Streak leaderboards:** Not shown in UI. Streak boards aren't configured in ASC and silently no-op. Streak ID *constants* stay in `GameCenterManager.Leaderboard` (deletion is a separate cleanup PR after a grep audit).
- **In-game "challenge a friend":** Removed entirely. The only surface was `FriendProfileView.challengeButton`, which generated `prisma://challenge?...` URLs with no handler — dead feature. Re-adding a working invite flow is **out of scope** for this slice.
- **ASC achievement art:** SF Symbol + gradient backdrop rendered to 512×512 PNGs via a small Swift CLI script (Anu's preference: ship velocity over hand-designed art, replaceable post-launch).
- **Push-notification background mode:** Stays in `Custom-Info.plist`. Notifications are planned.
- **`StreakManager` itself:** Untouched. It still drives the `streak_3/7/30` achievements and the in-app streak UI on the You tab.

---

## Phase 1 — what's done

All code changes landed via Xcode MCP `XcodeWrite` / `XcodeUpdate`. Files touched:

**New files (in new `Features/Leaderboard/` group):**
- `LeaderboardTabView.swift` — tab root, segmented picker, owns `GKAccessPoint` lifecycle
- `LeaderboardContent.swift` — extracted body of old `LeaderboardView`; now owns supporting types (`LeaderboardEntry`, `LeaderboardScope`, `LeaderboardMetric`, `GamePickerChip`, `RankRow`)
- `FriendsListContent.swift` — extracted body of old `FriendsTabView`; now owns the `GKPlayer: Identifiable` retroactive conformance

**Reduced to thin wrappers (will be deleted in Phase 2):**
- `Features/Profile/LeaderboardView.swift` (29 lines)
- `Features/Friends/FriendsTabView.swift` (32 lines)

**Modified:**
- `ContentView.swift` — tab renamed, root swapped to `LeaderboardTabView()`, `GKAccessPoint` toggle relocated
- `Features/Profile/ProfileView.swift` — `gameCenterPlaceholder` block + method removed
- `Features/Profile/ProfileSectionPreferences.swift` — `showLeaderboards` property removed; one-shot `UserDefaults.removeObject(forKey: "profile.showLeaderboards")` added in `init()` to clean existing installs
- `Features/Profile/ProfileCustomizeSheet.swift` — "Leaderboards" `SectionToggle` row removed

**Static audit results (grep-verified):**
- Every type/struct/extension declared exactly once — no duplicate symbols
- No remaining references to `showLeaderboards` or `gameCenterPlaceholder` outside intentional comments + the legacy-key cleanup call
- `ContentView` references `LeaderboardTabView` which exists in the new group

---

## What's blocked

**Phase 1 task 1.9 — Build cleanly.** The Xcode MCP `BuildProject`, `XcodeListNavigatorIssues`, and `XcodeRefreshCodeIssuesInFile` tools all timed out after 4 minutes in the previous session. Static audit gave high confidence in correctness, but a real build was never run.

**What Anu needs to do (or what you can do in Cowork via terminal):**

Option A (Anu, in Xcode): cmd-B. Report any errors.

Option B (you, in Cowork via integrated terminal):
```bash
cd /Users/anugnana/Library/Projects/Prisma/Prisma
xcodebuild -project Prisma.xcodeproj -scheme Prisma -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -50
```

If errors surface, fix them before starting Phase 2. If clean, mark task 1.9 ✅ in the tracker and proceed.

---

## What's next once the build is green

**Phase 2 (~half a day, see tracker for the 8-task breakdown):**
1. Remove `LeaderboardMetric` enum + Metric `Picker` from `LeaderboardContent.swift`
2. Simplify `leaderboardID(for:)` to always return `...daily.best`
3. Delete `challengeButton` from `FriendProfileView.swift` (lines ~130–148, plus call site at ~67–69 — pre-grepped, no other references)
4. Delete the two Phase 1 wrapper files (`LeaderboardView.swift`, `FriendsTabView.swift`)
5. Grep `ScoreManager.swift` for `*.daily.streak` references; remove submissions (do **not** touch `StreakManager`)
6. Build cleanly + manual smoke test

**Then Phase 3, 4, 5 in sequence.** Phase 4 (ASC config) and parts of Phase 5 (asset audit, screenshots, ASC copy) need Anu's account access — those tasks are flagged "Anu" in the tracker.

---

## Working preferences (carry these forward)

These shaped the previous session's collaboration style — keep them:

- **Always check before assuming.** Read the actual files before editing. Use grep before guessing. The previous session caught a duplicate-symbol bug only because it grep-audited type declarations after writing — same discipline pays off here.
- **Update the task tracker in real time, not retroactively.** Every completed task gets a status flip + a one-line note. The tracker is the source of truth, not the conversation.
- **Flag uncertainty honestly.** If a tool times out or a verification can't run, mark the task ⚠️ and tell Anu what they need to do. Don't claim ✅ for unverified work.
- **Ask before destructive moves.** Confirm with Anu before deleting files, changing project settings, or touching anything in `StreakManager` or game-result persistence.
- **Surface the smallest set of decisions Anu actually has to make.** Use the question-options pattern (single_select / multi_select) when there's a real branch — don't ask for confirmation on things that are already locked.
- **No emojis.** No marketing-speak. Direct prose, real recommendations.

---

## Known constraints in this environment

- **macOS host** — Anu's machine, paths under `/Users/anugnana/`.
- **Xcode MCP tools available** in Cowork via the same MCP server — but `BuildProject` was unreliable in the previous session. Prefer `xcodebuild` from the integrated terminal for builds.
- **Filesystem MCP scope** in the previous session was `/Users/anugnana/Library/Projects/Prisma/Prisma` — one level *below* where the original planning docs live. Cowork should have direct access to the full project tree, which is better.
- **No deployed device** — all testing in simulator unless Anu plugs in an iPhone.
- **GC sandbox vs. prod is a real pain point.** Sandbox scores don't transfer to prod. Always use a fresh sandbox tester for verification per `GAME_CENTER_STATUS.md` checklist.

---

## First message to paste into Cowork

Copy-paste this verbatim as your opening prompt to the new Cowork session:

> I'm continuing an iOS engineering project from a previous Claude session. Before doing any work, please read these files in order:
>
> 1. `/Users/anugnana/Library/Projects/Prisma/Prisma/COWORK_HANDOFF.md` — handoff brief (start here)
> 2. `/Users/anugnana/Library/Projects/Prisma/Prisma/LEADERBOARD_RESTRUCTURE_PLAN.md` — strategy doc
> 3. `/Users/anugnana/Library/Projects/Prisma/Prisma/LEADERBOARD_RESTRUCTURE_TASKS.md` — live task tracker
> 4. `/Users/anugnana/Library/Projects/Prisma/game_center_plan.md` — original Game Center design
> 5. `/Users/anugnana/Library/Projects/Prisma/GAME_CENTER_STATUS.md` — what's currently wired in GC
> 6. `/Users/anugnana/Library/Projects/Prisma/app_summary.md` — app state overview
>
> After reading, summarize back to me:
> - Where we are in the plan
> - What the immediate next action is
> - Anything in the docs that looks stale, contradictory, or unclear
>
> Don't write any code or make any edits until I confirm your summary is right.

---

*End of handoff brief. The next session reads this, then the plan, then the tracker, then asks before acting. That's the protocol.*
