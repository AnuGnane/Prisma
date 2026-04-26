# Prisma — Leaderboard Restructure & TestFlight Readiness Plan

**Owner:** Anu
**Drafted:** 2026-04-23
**Status:** Approved — implementation starting with Phase 1

---

## 1. Context

Prisma currently ships three tabs: **Games**, **Friends**, **You**. The Friends tab is a working friends-list surface (today's status per friend, avatars, head-to-head stats). Leaderboards live on the You tab behind a `NavigationLink` to `LeaderboardView`, which has Game / Metric / Scope pickers.

The goals of this restructure are:

1. Consolidate the social layer. "Friends" and "Rankings" are two views of the same dataset (Game Center scores). They should live in one tab with a segmented control between them.
2. Remove features that look shippable but silently no-op (streak leaderboards, friend-challenge button).
3. Polish the rough edges (empty states, error states, ASC achievement config, Info.plist, icon) so the build is genuinely TestFlight-ready.

## 2. Locked-in decisions

- **Tab rename:** `Friends` → `Leaderboard` (icon: `trophy.fill`).
- **Layout:** Segmented toggle at the top of the Leaderboard tab — `Rankings` | `Friends`.
- **Segment memory:** `@SceneStorage("leaderboardSegment")` so the picker state survives tab switches and relaunches.
- **Streaks:** Not shown in the UI. `LeaderboardView` loses its Metric picker. Streak leaderboard IDs stay in `GameCenterManager.Leaderboard` constants (removing them risks breaking references we haven't audited yet; real cleanup is a separate PR).
- **In-game "challenge a friend":** Removed. The only surface is `FriendProfileView.challengeButton`, which generates a `prisma://challenge?...` URL with no matching handler — dead feature, safe to delete.
- **ASC achievement art:** SF Symbols + gradient backdrop, rendered at 512×512.
- **Push notifications:** Keep the `remote-notification` background mode — notifications are planned.

## 3. What already exists (baseline)

Grounded inventory so the plan doesn't re-invent what's there.

### 3.1 Friends feature (already working)
- `Features/Friends/FriendsTabView.swift` — root view of the current Friends tab, with auth gate state machine (unknown / notDetermined / denied / restricted / authorized), pull-to-refresh, skeleton list, and scene-phase-based auto-refresh.
- `Features/Friends/FriendRow.swift` — avatar + display name + "X/5 solved today" pill + per-game mini-icons.
- `Features/Friends/FriendProfileView.swift` — per-friend detail sheet with header, H2H banner, five `GameStatCard`s, and (to be removed) the challenge button.
- `Features/Friends/FriendsAuthGateView.swift` — permission-request surface for `.notDetermined` / `.denied` / `.restricted`.
- `Features/Friends/FriendsModels.swift` — `FriendGameStats`, `FriendTodaySummary`, `HeadToHead`.
- `Core/Services/FriendsService.swift` — `@Observable @MainActor` singleton wrapping `GKLocalPlayer.loadFriends` + the batched-`GKLeaderboard.loadEntries` pipeline, with a 30s summary cache.

### 3.2 Leaderboard feature (already working)
- `Features/Profile/LeaderboardView.swift` — `NavigationStack` + horizontal game picker, Metric picker (Best/Streak), Scope picker (Today/All-Time/Friends), `GKLeaderboard.loadEntries` driver. Handles unauthenticated state with a Settings CTA.

### 3.3 Supporting systems
- `Core/Services/GameCenterManager.swift` — auth handler, pending-submission queue for pre-auth calls, daily-submission dedup, all leaderboard + achievement IDs as string constants.
- `Core/Services/ScoreManager.swift` — central funnel for Circuit; other games use per-game inline submissions. (Per `GAME_CENTER_STATUS.md`, unifying these is a known future refactor — out of scope here.)
- `Features/Profile/ProfileView.swift` — "You" tab; has a `gameCenterPlaceholder` `NavigationLink` to `LeaderboardView` gated by `prefs.showLeaderboards`.
- `Features/Profile/ProfileSectionPreferences.swift` — `@Observable` holder of per-section toggle state backed by `UserDefaults`.
- `Features/Profile/ProfileCustomizeSheet.swift` — toggle UI for those preferences.

### 3.4 Confirmed dead surfaces
- **`FriendProfileView.challengeButton`** (`FriendProfileView.swift:130–148` + call site at `:67–69`). Generates `prisma://challenge?friend=...`. A project-wide grep for `onOpenURL`, `CFBundleURLSchemes`, and `prisma://` returns exactly one hit: the generator itself. No handler exists. Safe to remove.
- **Streak leaderboard IDs in the UI.** `LeaderboardView.leaderboardID(for:metric:)` maps to `.signalsDailyStreak`, `.archiveDailyStreak`, etc., which are never configured in ASC. Submissions silently no-op. UI references get deleted; the string constants stay.

## 4. Phased delivery

Each phase compiles cleanly on its own. You can ship at any boundary.

### Phase 1 — Tab restructure (~1 day)

**Goal:** rename the tab, build the segmented-tab root, migrate content into it with zero regressions.

Files touched:

| File | Change |
|---|---|
| `ContentView.swift` | `Tab("Friends", systemImage: "person.2.fill")` → `Tab("Leaderboard", systemImage: "trophy.fill")`. Swap `FriendsTabView()` for `LeaderboardTabView()`. |
| `Features/Leaderboard/LeaderboardTabView.swift` *(new)* | New tab root. Owns `@SceneStorage("leaderboardSegment") private var segment: Segment = .rankings` and renders a segmented `Picker` pinned under the nav title. Manages `GKAccessPoint` lifecycle (currently on `FriendsTabView`). |
| `Features/Leaderboard/LeaderboardContent.swift` *(new — extracted)* | Existing `LeaderboardView` body without its `NavigationStack` — so it can nest under `LeaderboardTabView`'s stack. |
| `Features/Leaderboard/FriendsListContent.swift` *(new — extracted)* | Existing `FriendsTabView` body without its `NavigationStack`, for the same reason. |
| `Features/Friends/FriendsTabView.swift` | Kept as a thin wrapper around `FriendsListContent` for previews and any lingering callers. Flagged for deletion in Phase 2. |
| `Features/Profile/LeaderboardView.swift` | Kept as a thin wrapper around `LeaderboardContent` for previews. Flagged for deletion in Phase 2. |
| `Features/Profile/ProfileView.swift` | Delete `gameCenterPlaceholder` and the `if prefs.showLeaderboards { … }` block. |
| `Features/Profile/ProfileSectionPreferences.swift` | Delete `showLeaderboards` property + its `UserDefaults` key (`profile.showLeaderboards`). |
| `Features/Profile/ProfileCustomizeSheet.swift` | Delete the "Leaderboards" `SectionToggle` row. |

**New folder structure:** create `Features/Leaderboard/` to host the tab root and its two content children. `Features/Friends/` stays for the sheet + friend-only types.

**Tab root layout:**

```
┌─────────────────────────────────────┐
│          Leaderboard                │  ← large nav title
│  ┌──────────────┬──────────────┐    │
│  │  Rankings    │   Friends    │    │  ← segmented picker, pinned
│  └──────────────┴──────────────┘    │
│                                     │
│  [ content for selected segment ]   │
└─────────────────────────────────────┘
```

Tapping a friend row in the `Friends` segment still opens `FriendProfileView` via `.sheet` as today.

### Phase 2 — Streak UI cleanup + dead-code removal (~0.5 day)

**Goal:** strip the Metric picker and the broken challenge button; delete thin wrappers from Phase 1.

Files touched:

| File | Change |
|---|---|
| `Features/Leaderboard/LeaderboardContent.swift` | Remove `@State var selectedMetric`, the entire Metric `Picker` block, `.task(id: selectedMetric)`, and the `enum LeaderboardMetric`. Simplify `leaderboardID(for:)` to always return `...daily.best`. |
| `Features/Friends/FriendProfileView.swift` | Delete `challengeButton` method (lines ~130–148) and its call site in `profileContent` (lines ~67–69). Update header doc comment to drop the "Share / challenge button" bullet. |
| `Features/Profile/LeaderboardView.swift` | Delete file (the Phase 1 wrapper). Preview moves into `LeaderboardContent.swift`. |
| `Features/Friends/FriendsTabView.swift` | Delete file (the Phase 1 wrapper). Preview moves into `FriendsListContent.swift`. |
| `Core/Services/ScoreManager.swift` | Remove any calls that submit to `*.daily.streak` leaderboard IDs. **Do not touch `StreakManager`** — the in-app streak UI and the `streak_3/7/30` achievements still depend on it. Streak string constants in `GameCenterManager.Leaderboard` stay for now. |

### Phase 3 — Empty-state & error-state polish (~1 day)

**Goal:** one consistent shape for "nothing here yet" and "something broke" everywhere.

Add `Core/UI/AppEmptyState.swift` — a thin wrapper around `ContentUnavailableView` with consistent padding, `AppTheme` tint, and an optional `retry: () -> Void`. Sweep these callers:

- `LeaderboardContent` — "No scores yet" / "Couldn't load scores"
- `FriendsListContent` — no friends / load error
- `FriendProfileView` — load error (with retry)
- `ProfileView.emptyDailySection` — no daily results yet
- Any game-view completion error paths — scan during the sweep

Draft the helper first, get Anu's sign-off on the visual, then do the sweep.

### Phase 4 — ASC achievement configuration (~0.5 day effort + image generation)

**Goal:** the 7 achievements from `GAME_CENTER_STATUS.md` marked ⚠️ get real ASC entries with localization and images.

**Art approach:** SF Symbol rendered at 512×512 with a gradient backdrop per game. A small Swift CLI script (`tools/gen_achievement_icons.swift`) will:
- Take a symbol name + hex gradient pair per achievement
- Render to PNG at 512×512 via `UIGraphicsImageRenderer`
- Output to `tools/achievement_images/`

**Per-achievement spec:**

| ID | Title | SF Symbol | Gradient (game accent) |
|---|---|---|---|
| `prisma.first_cargo` | Pack Your Bags | `shippingbox.fill` | cargo accent |
| `prisma.first_shift` | Word Mover | `slider.horizontal.3` | shift accent |
| `prisma.first_circuit` | Connected | `bolt.horizontal.fill` | circuit accent |
| `prisma.perfect_archive` | Dead Reckoning | `scope` | archive accent |
| `prisma.perfect_cargo` | Tetris Mode | `square.grid.3x3.fill` | cargo accent |
| `prisma.perfect_shift` | No Backsies | `arrow.uturn.backward.circle.fill` | shift accent |
| `prisma.perfect_circuit` | Par Excellence | `star.circle.fill` | circuit accent |

ASC localization draft lives in the task tracker (`LEADERBOARD_RESTRUCTURE_TASKS.md` § Phase 4).

### Phase 5 — TestFlight readiness audit (~1 day spread over a week)

**Code / project settings:**
- Bump `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`.
- Verify `PRODUCT_BUNDLE_IDENTIFIER` matches ASC.
- Confirm deployment target iOS 18.0+ is consistent across Debug / Release.
- `Custom-Info.plist` audit: add `ITSAppUsesNonExemptEncryption = false`, `LSApplicationCategoryType = public.app-category.puzzle-games`, confirm `CFBundleDisplayName`. Keep the `remote-notification` background mode per Anu's note.

**Assets (cannot be enumerated via MCP tools — manual in Xcode):**
- Open `Assets.xcassets/AppIcon` and confirm every slot populated, especially the 1024×1024 marketing slot.
- Verify `Assets.xcassets/AccentColor` exists (used for system-rendered UI).
- Confirm launch screen — `UILaunchScreen` key in Info.plist or a storyboard.

**Runtime verification:**
- Fresh GC sandbox tester → full checklist from `GAME_CENTER_STATUS.md` § Testing Checklist.
- Cold launch on a real iPhone (< 2s to first interactive frame).
- GC unauthenticated + airplane mode smoke test.

**ASC submission prep:**
- Screenshots — 6.5" and 6.9" iPhone sizes.
- Description, keywords, support URL, privacy policy URL.
- "What to Test" notes.

## 5. Out of scope for this slice

To keep the change set shippable, these don't ship with this work:
- Unifying per-game score submission through `ScoreManager` (known inconsistency — Circuit routes through `ScoreManager`, others don't).
- CloudKit sharing for friend leaderboards (local + GC only, per `game_center_plan.md`).
- In-game invite/matchmaker integration — the old `ShareLink` is removed; no replacement flow is being added.
- Removing `*.daily.streak` string constants from `GameCenterManager.Leaderboard` — defer until after a grep-clean PR.
- New game-view UIs or gameplay changes.

## 6. Risks

- **Phase 2 deletion of Phase 1 wrappers.** If I miss a preview reference or a forgotten call site, build breaks. Mitigation: the wrappers exist precisely so Phase 1 can ship without needing to find every reference; Phase 2 greps for them before deletion.
- **ASC delays.** Seven achievements with images can take a review cycle. Mitigation: Phase 4 runs in parallel with Phase 5 — the app ships either way; achievements quietly unlock once ASC approves the entries.
- **Sandbox vs. production GC weirdness.** Sandbox scores are isolated from prod. All testing in Phase 5 assumes fresh sandbox testers, not the dev's real Apple ID.

## 7. Progress tracking

Live task status lives in `LEADERBOARD_RESTRUCTURE_TASKS.md` next to this file. Every task has a checkbox, owner, and notes column. Update it as work lands, not retroactively.
