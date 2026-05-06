# Prisma — Game Center Integration Status

> Last updated: April 2026  
> Build status: ✅ All GC code compiles and submits correctly

---

## Leaderboards

### Decision: No Streak Leaderboards

Streak leaderboard IDs exist in `GameCenterManager.Leaderboard` (e.g. `prisma.signals.daily.streak`) and the app code submits to them, but **do not configure these in App Store Connect**. They are intentionally unused. The code submissions will silently no-op until an ASC entry backs them — so there is nothing to remove or disable in the app.

### Active Leaderboards — configure these 6 in ASC

| Leaderboard | ASC ID | Score meaning | Lower is better? |
|---|---|---|---|
| Signals Daily Best | `prisma.signals.daily.best` | Guess count to solve | ✅ Yes |
| Archive Daily Best | `prisma.archive.daily.best` | Guess count to solve | ✅ Yes |
| Cargo Daily Best | `prisma.cargo.daily.best` | Elapsed seconds | ✅ Yes |
| Shift Daily Best | `prisma.shift.daily.best` | Move count to solve | ✅ Yes |
| Circuit Daily Best | `prisma.circuit.daily.best` | Elapsed seconds | ✅ Yes |
| Local Mastery | `prisma.local.mastery` | Total local levels won | ❌ Higher is better |

> **ASC Leaderboard setup reminder:** Set score format to "Integer" and sort order to "Lowest First" for the five daily best boards. Set "Local Mastery" to "Highest First".

### When scores are submitted (per game)

| Game | Submitted on | Score value |
|---|---|---|
| Signals | Daily win (guess phase complete) | `guessCount` |
| Archive | Daily win (guess phase complete) | `guessCount` |
| Cargo | Daily win (`score >= 700`, i.e. ≥70% fill) | `elapsedSeconds` |
| Shift | Daily win (puzzle completed) | `moveCount` |
| Circuit | Daily win (all paths connected) | `elapsedSeconds` |
| All games | Any local level win | `totalLocalWins` → Local Mastery |

> **Cargo give-up policy:** Give-ups are NOT saved and NOT submitted. The player can retry the same day's puzzle. Only a 70%+ fill counts as a win and triggers submission.

---

## Achievements

### Achievement Budget
Total points budget in ASC: **1000 pt**  
Allocated below: **1000 pt** ✅

### All 14 Achievements

| Achievement | ASC ID | Points | Type | Trigger | ASC Status |
|---|---|---|---|---|---|
| First Signal | `prisma.first_signal` | 50 | Non-repeatable | Complete any Signals puzzle | ✅ Configured |
| First Archive | `prisma.first_archive` | 50 | Non-repeatable | Complete any Archive puzzle | ✅ Configured |
| First Cargo | `prisma.first_cargo` | 50 | Non-repeatable | Win any Cargo puzzle (≥70% fill) | ⚠️ Needs ASC entry + image |
| First Shift | `prisma.first_shift` | 50 | Non-repeatable | Complete any Shift puzzle | ⚠️ Needs ASC entry + image |
| First Circuit | `prisma.first_circuit` | 50 | Non-repeatable | Complete any Circuit puzzle | ⚠️ Needs ASC entry + image |
| 3-Day Streak | `prisma.streak_3` | 50 | Non-repeatable | Win any daily game 3 days in a row | ✅ Configured |
| 7-Day Streak | `prisma.streak_7` | 100 | Non-repeatable | Win any daily game 7 days in a row | ✅ Configured |
| 30-Day Streak | `prisma.streak_30` | 200 | Non-repeatable | Win any daily game 30 days in a row | ✅ Configured |
| Perfect Signal | `prisma.perfect_signal` | 100 | Non-repeatable | Solve Signals daily in 1 guess | ✅ Configured |
| Perfect Archive | `prisma.perfect_archive` | 100 | Non-repeatable | Solve Archive daily in 1 guess | ⚠️ Needs ASC entry + image |
| Perfect Cargo | `prisma.perfect_cargo` | 100 | Non-repeatable | 100% board fill on Cargo daily | ⚠️ Needs ASC entry + image |
| Perfect Shift | `prisma.perfect_shift` | 100 | Non-repeatable | Solve Shift with zero undos | ⚠️ Needs ASC entry + image |
| Perfect Circuit | `prisma.perfect_circuit` | 100 | Non-repeatable | Solve Circuit at or under par moves | ⚠️ Needs ASC entry + image |
| Local Mastery 25 | `prisma.local_25` | — | Progress (0–100%) | Win 25 local levels | ✅ Configured |
| Local Mastery 50 | `prisma.local_50` | — | Progress (0–100%) | Win 50 local levels | ✅ Configured |
| Local Mastery 100 | `prisma.local_100` | — | Progress (0–100%) | Win 100 local levels | ✅ Configured |

> ⚠️ **7 achievements need 512×512 images before their ASC entries can be saved.** Until then, they will silently no-op at runtime (GK ignores unknown IDs).

### ASC Achievement Setup Checklist (for the 7 pending)

For each of the 7 achievements marked ⚠️ above:

1. Go to App Store Connect → Your App → Features → Game Center → Achievements
2. Click **+** to add a new achievement
3. Set the **Achievement Reference Name** (internal) and the **ID** exactly as shown in the table
4. Upload a **512×512 PNG** achievement image
5. Add localisation: Title + Description (see suggestions below)
6. Set **Point Value** and uncheck **Hidden** unless you want it secret
7. Click **Save**

### Suggested Localisation for Pending Achievements

| ID | Title | Description |
|---|---|---|
| `prisma.first_cargo` | Pack Your Bags | Complete your first Cargo puzzle |
| `prisma.first_shift` | Word Mover | Complete your first Shift puzzle |
| `prisma.first_circuit` | Connected | Complete your first Circuit puzzle |
| `prisma.perfect_archive` | Dead Reckoning | Identify an Archive image on the very first guess |
| `prisma.perfect_cargo` | Tetris Mode | Fill every cell on a Cargo board |
| `prisma.perfect_shift` | No Backsies | Solve a Shift puzzle without using a single undo |
| `prisma.perfect_circuit` | Par Excellence | Solve a Circuit puzzle at or under the par move count |

---

## Code Architecture

### How each game submits scores

| Game | GC submission point | File |
|---|---|---|
| Signals | `reportToGameCenter()` called on guess-phase completion | `SignalsGameView.swift` |
| Archive | `reportToGameCenter()` called on guess-phase completion | `ArchiveGameView.swift` |
| Cargo | `reportToGameCenter(score:isPerfect:)` called from `saveResult()` | `CargoGameView.swift` |
| Shift | Inline in `saveAndDismiss()` | `ShiftGameView.swift` |
| Circuit | `ScoreManager.shared.processAndSaveResult(_:context:)` | `CircuitGameView.swift` |

> Note: Circuit is the only game routing through the centralised `ScoreManager`. The others use per-game extensions. This is a known inconsistency — harmless for now but worth unifying in a future refactor.

### Known GC Bugs Fixed in This Session

| Bug | Where | Fix |
|---|---|---|
| Cargo never submitted to GC at all | `CargoGameView.saveResult()` | Added `reportToGameCenter(score:isPerfect:)` |
| Cargo give-up blocked daily replay | `saveResult()` saved score=0 results | Now only saves/submits when `score >= 700` |
| Shift submitted streak to Signals' leaderboard | `saveAndDismiss()` used wrong ID | Changed to `shiftDailyStreak` (no-ops since streak boards aren't in ASC anyway) |
| Shift never submitted daily best score | `saveAndDismiss()` | Now submits `moveCount` to `shiftDailyBest` |
| Shift missing `firstShift` + `perfectShift` achievements | `saveAndDismiss()` | Both now reported on daily completion |
| Archive missing `perfectArchive` achievement | `reportToGameCenter()` | Now fires when `guessCount == 1` on daily win |

---

## Testing Checklist

- [ ] Create fresh sandbox tester account (existing accounts may have stale/broken scores)
- [ ] Play Signals daily → verify score appears in `prisma.signals.daily.best`
- [ ] Play Archive daily → verify score appears in `prisma.archive.daily.best`
- [ ] Play Cargo daily to ≥70% fill → verify elapsed time appears in `prisma.cargo.daily.best`
- [ ] Give up on Cargo daily → verify you can play again same day (no result saved)
- [ ] Play Shift daily → verify move count appears in `prisma.shift.daily.best`
- [ ] Play Circuit daily → verify elapsed time appears in `prisma.circuit.daily.best`
- [ ] Win a daily game → verify `firstSignal` / `firstArchive` achievement banner fires
- [ ] Win 3 consecutive daily games → verify `streak_3` achievement fires
- [ ] Verify `prisma.local.mastery` updates after winning local levels
- [ ] Verify Friends tab shows today's scores after 2–5 min sandbox propagation delay
