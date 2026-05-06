# TestFlight Tester Notes — Prisma Puzzles v1.0 (Build 2)

Drafted 2026-04-25, updated 2026-04-26. Paste the body of this file into App Store Connect → TestFlight → Build → "What to Test" before inviting external testers. Internal testers don't see this field but it's useful as our own QA checklist.

---

## What to test

Welcome, and thank you for testing Prisma — five daily puzzle games (Signals, Archive, Cargo, Shift, Circuit) plus a 150-level archive in each. This is our first TestFlight build and we'd love feedback on:

**Daily play**
- Try each of the five daily games at least once. Each one resets at midnight local time.
- Confirm the result overlay shows your score, time, and a Share button.
- Tap Share — does the share text describe the game and your result clearly?

**Local archive**
- Open the Games tab → tap any game → "Local levels". You should see a grid of 150 numbered tiles.
- Play L1 of each game to confirm the level loads and a save resumes correctly if you back out.
- Try a higher level (L75+) to confirm difficulty scaling feels reasonable.

**Streaks and badges**
- Win at least one daily to start your streak. Tomorrow, win again — your streak counter on the You tab should read "2 days".
- Open the You tab and check the Badges grid — earned badges should show in colour, locked badges greyed out.

**Game Center**
- On first launch you'll be asked to sign into Game Center. Please accept.
- The first time you open the Leaderboard tab you'll be asked for permission to see your friends' scores. Please tap Allow so we can verify the friends features.
- Open the Leaderboard tab → Rankings segment. Tap each game icon to switch boards. Today's friends-only scores should load (or show an empty state if no friends have played that game today).
- Open the Leaderboard tab → Friends segment. Tap a friend (if you have any GC friends) to see their per-game stats.
- Tap the "+" person icon at the top right of the Friends segment — the Game Center dashboard should open so you can search for and add friends.
- Win a daily — confirm a Game Center achievement banner appears for the matching first-win achievement (Tuned In, Time Traveller, Pack Your Bags, Word Mover, or Connected).

**Known limitations in this build**
- "Perfect" achievements (Cold Read, Dead Reckoning, Tetris Mode, No Backsies, Par Excellence) are wired in code but not yet configured on Apple's side, so banners for those won't appear in this build. They'll come on in a future TestFlight.
- Streak and "100 levels won" milestones are tracked in-app via the Badges grid only — we deliberately did not put them on Game Center.
- If you sign out of Game Center mid-session, the Leaderboard tab falls back to a "Sign in" state. To recover, sign back in via Settings → Game Center.

**What we'd love to hear**
- Anything that crashes, freezes, or looks visually broken.
- Daily puzzles that feel too easy or too hard for an early level.
- Any moment where the app's wording was confusing or unhelpful.
- Whether your daily streak counter feels accurate the day after you play.
- How the Friends tab feels when you open it cold — empty / full / load delay.

Thank you! Bug reports go directly through TestFlight (use the "Send Beta Feedback" option) or feel free to email me directly.

---

## (Internal) QA matrix before each TestFlight push

Paste this into a checklist; complete before tagging a build for external review.

- [ ] Cold launch on real iPhone < 2s to first interactive frame.
- [ ] Sign-in to Game Center prompt appears on first launch with a sandbox account.
- [ ] Friends-permission prompt appears on first Leaderboard tab visit.
- [ ] All five dailies playable and submitting scores to GC sandbox.
- [ ] Local archive: at least one level played per game without crash.
- [ ] You tab streak counter increments correctly across two consecutive sandbox days (or use the Date override in Settings if available).
- [ ] Airplane-mode smoke: open every tab and back out — no crashes; Leaderboard / Friends show "Couldn't load" or "Sign in" states cleanly.
- [ ] Achievement banner fires for at least one first-win achievement (verifies the GC pipe).
- [ ] Settings flag confirmed: `ITSAppUsesNonExemptEncryption = false` (skips export-compliance dialog at submission).
