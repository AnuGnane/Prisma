# Prisma Puzzles — Product Roadmap

Last updated: 2026-05-05

A living document of ideas, polish work, and future features organised by priority. Items are grouped into three horizons:

- **v1.0 Polish** — things to tighten before or alongside the first public release
- **v1.1 Features** — second build after launch, driven by TestFlight feedback
- **v2.0 Vision** — larger bets for when the foundation is stable

---

## v1.0 Polish — Ship-quality refinements

These are low-risk, high-impact improvements that can ship in build 4 alongside the review response.

### 🏆 Game Center & Leaderboards

| Item | Detail | Effort |
|------|--------|--------|
| **Configure 5 perfect-win achievements in ASC** | Code is wired, PNGs generated. Just needs ASC entries: Cold Read, Dead Reckoning, Tetris Mode, No Backsies, Par Excellence | 15 min |
| **"Your rank" shows 0 when not played** | Already fixed this session — hiding rank when `score == 0` | ✅ Done |
| **Score units on leaderboard** | Already fixed — "3 guesses", "42s", "1:45" | ✅ Done |

### 🎨 Visual & UX Polish

| Item | Detail | Effort |
|------|--------|--------|
| **Stat card says "/ 100" but catalog is 150** | `ProfileView.StatCard` hardcodes `Text("/ 100")` and `total: 100` in the progress bar. Should read from the actual level count (150) | 5 min |
| **Badge descriptions reference 100 levels** | `Badge.signalsMaster` etc. say "Win all 100 Signals local levels" — update to 150 | 5 min |
| **Daily result row metrics for time-based games** | `DailyResultRow` shows "X guesses" for all games. Cargo/Shift/Circuit should show formatted time like the leaderboard does | 15 min |
| **Missing `circuitMaster` badge** | Badges exist for Signals, Archive, Cargo, Shift mastery but no Circuit equivalent. Add `circuitMaster` to `Badge` enum | 10 min |
| **Notification body mentions 4 games** | `NotificationManager` says "Signals, Archive, Cargo, Shift" — Circuit is missing from the copy | 1 min |

### 🔧 Technical Hygiene

| Item | Detail | Effort |
|------|--------|--------|
| **Harden Circuit tests** | Replace placeholder assertions (task #40 from app_summary) | 1 hr |
| **Remove diagnostic logging** | Strip `[FriendsService]` print statements before App Store build, or gate behind `#if DEBUG` | 10 min |
| **Audit `try?` silent failures** | Several GC calls use `try?` which swallows errors. Consider logging failures at minimum | 30 min |

---

## v1.1 Features — First update after launch

These are features that add genuine value and should be informed by real TestFlight usage data.

### 📊 Enhanced Stats & Analytics

| Item | Detail | Impact |
|------|--------|--------|
| **Personal best tracking per game** | Show PB on the game detail screen — "Your best: 2 guesses" for Signals, "Your best: 38s" for Cargo. Currently no surface for this data even though `LevelProgress` stores it | Medium |
| **Game-specific solve time distribution** | Expand `SolveTimeStatsView` to show per-game breakdowns, not just aggregate. A small histogram or sparkline of last 20 solves | Medium |
| **Daily completion summary** | After completing all 5 daily puzzles, show a "Daily Sweep" celebration with aggregate stats — total time across all games, number of perfect clears | High |
| **Weekly recap (push notification)** | Sunday evening notification: "This week: 5/7 streak, 2 PBs, 35 levels cleared." Drives re-engagement without being annoying | Medium |

### 🤝 Social Features

| Item | Detail | Impact |
|------|--------|--------|
| **Share card for daily results** | Generate a shareable image (using `ImageRenderer`) showing today's results across all 5 games — like Wordle's share grid but for Prisma. Include the colorful game icons and score summary | High |
| **Friend challenge notifications** | When a friend posts a score, optionally notify: "ritzzy28 just solved Signals in 3 guesses — can you beat it?" Requires push notification entitlement | High |
| **Head-to-head today view** | On the friend profile, add a "Today" segment alongside the current all-time H2H. Shows who's winning today's games | Medium |
| **Rematch nudge** | If a friend beats your daily score, show a subtle banner on the Games tab: "ritzzy28 beat your Signals score — play again tomorrow" | Low |

### 🎮 Gameplay Improvements

| Item | Detail | Impact |
|------|--------|--------|
| **Hints system** | Optional hints for each game (costs a star or adds to guess count). E.g., Signals reveals one correct digit position, Archive narrows decade range, Circuit highlights one correct path segment | High |
| **Difficulty selector for daily puzzles** | Easy / Normal / Hard variants of the daily. Easy reduces grid size or gives more guesses. Separate leaderboards per difficulty | Medium |
| **Undo history visualization** | For Circuit, show a ghost trail of the last few moves so the player can see their exploration path | Low |
| **Colorblind mode** | Alternative color palettes for game elements. Particularly important for Signals (color-coded feedback) and Circuit (path highlighting) | Medium |
| **Sound & haptic settings per game** | The settings view has a global sound toggle. Add per-game granularity — some players may want haptics in Circuit but not in Archive | Low |

### 🌍 Localisation & Accessibility

| Item | Detail | Impact |
|------|--------|--------|
| **Localisation pass** | Prioritise: Spanish, French, German, Japanese, Portuguese (BR), Arabic (RTL). Use Localizable.xcstrings with manual extraction | High |
| **VoiceOver audit** | Ensure all game boards are navigable. Circuit paths and Cargo piece placement need custom accessibility actions | High |
| **Dynamic Type stress test** | Verify all views at XXXL and AX sizes. Known risk: `StatCard` and `StreakPill` may clip at extreme sizes | Medium |

---

## v2.0 Vision — Larger bets

These are bigger features that would significantly evolve the product. Each needs a design phase.

### 🧩 New Game Modes

| Idea | Concept | Notes |
|------|---------|-------|
| **Spectrum** (colour logic) | Given clues about RGB/HSL values, deduce the target colour. A visual twist on Mastermind | Unique — no competitor does this |
| **Echo** (audio memory) | Listen to a sequence of tones/rhythms and reproduce them. Progressive difficulty with more notes per round | Differentiator — no daily audio puzzle exists |
| **Grid** (nonogram/picross) | Classic picture logic puzzle with daily themes. Large community demand for daily nonograms | Proven format, high retention |
| **Vault** (word search variant) | Find hidden words in a grid where letters shift after each find, changing the remaining puzzle | Novel twist on a classic |

### 📱 Platform Expansion

| Item | Detail |
|------|--------|
| **iPad support** | Intentionally dropped in Phase 5 for launch simplicity. Re-enable with adaptive layouts — games like Cargo and Circuit benefit from the larger canvas |
| **watchOS complication** | Show daily streak count and completion status as a watch complication. Tap to see which games are left today |
| **Widgets (Lock Screen + Home Screen)** | "Today's progress" widget showing 5 game icons with completion checkmarks. Lock screen widget shows streak count |
| **App Intents / Shortcuts** | "Start today's Signals" Siri shortcut. "How's my streak?" shortcut that returns the current count |
| **Live Activities** | During a timed game (Cargo/Circuit), show elapsed time on the Dynamic Island. Debatable UX value but high visibility |

### 💰 Monetisation (if desired)

| Model | Approach | Risk |
|-------|----------|------|
| **Prisma Pro (tip jar)** | One-time purchase ($2.99) that unlocks cosmetic themes, custom app icons, and an animated profile badge. No gameplay gates | Low risk — purely cosmetic |
| **Season Pass** | Monthly ($0.99) for bonus daily puzzles (6th game slot), exclusive badges, and early access to new game modes | Medium risk — creates content treadmill |
| **Ad-supported free tier** | Banner ad on the home screen for free users; Pro removes it. Given the "no ads" positioning in v1.0, this is a brand risk | High risk — breaks launch promise |

> **Recommendation:** The tip jar model aligns best with the current "no ads, no IAP" ethos. It's honest, low-friction, and rewards engaged players without gating content.

### 🏗️ Technical Foundation

| Item | Detail |
|------|--------|
| **Server-side daily puzzle generation** | Currently, dailies are generated client-side with deterministic seeds. A server component would enable themed events, holiday specials, and A/B testing difficulty curves |
| **CloudKit Dashboard analytics** | Build a lightweight admin view that queries CKRecordZone metadata to understand sync patterns, error rates, and active users |
| **Automated screenshot pipeline** | Wire up the `asc-shots-pipeline` skill for CI-driven screenshot generation across devices and locales |
| **SwiftData migration strategy** | Plan for schema changes as new game modes add new result types. Define a versioned migration path now before v1.1 ships |

---

## Quick Wins — Can do today

These are things you could knock out in a single session:

1. **Fix "/ 100" → "/ 150" in StatCard** — 2 lines
2. **Fix badge descriptions to say 150** — 4 strings
3. **Add `circuitMaster` badge** — 1 new enum case + metadata
4. **Fix notification body to include Circuit** — 1 string
5. **Gate `[FriendsService]` logs behind `#if DEBUG`** — find/replace
6. **Configure perfect-win achievements in ASC** — 15 min in the dashboard

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-05-05 | Friends summary queries switched from `.friendsOnly` scope to player-specific `loadEntries(for:)` | `gamePlayerID` mismatch between `loadFriends()` and leaderboard entries caused silent 0/5 on some GC accounts |
| 2026-05-05 | Cargo daily GC gated on `isPerfect` only | Prevents incomplete solves from cluttering leaderboards |
| 2026-05-05 | Leaderboard scores display with units | Raw numbers were ambiguous — "42" could mean guesses or seconds |
| 2026-05-05 | `submittedDailyKeys` persisted to UserDefaults | Prevents duplicate GC submissions after app restart |
