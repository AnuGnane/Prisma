# App Review Response — Guideline 2.1 (v1.0, build 3)

Drafted 2026-04-26. Paste the body below into the Resolution Center reply in App Store Connect (App Review tab → reply to the reviewer's message). The same text can also be saved into App Information → App Review Information → Notes for future submissions.

Attach the physical-device screen recording (see "Recording instructions" further down) to the same Resolution Center reply.

---

## Response body — paste this into Resolution Center

```
Thank you for the review. Replying below to each of your six points.

1. Screen recording

A physical-device screen recording is attached to this message, captured on iPhone Air, iOS 26.4.2. The recording begins with the app launch and walks through the typical user flow:

- Cold launch from the home screen
- Onboarding / how-to-play sheet (first launch only)
- Games tab — overview of the five games
- One short play of each daily puzzle: Signals, Archive, Cargo, Shift, Circuit
- Local levels — tapping into the Cargo level archive, opening one level
- Leaderboard tab — Rankings segment (per-game daily friends leaderboard) and Friends segment (friends list and friend profile sheet)
- You tab — daily streak counter, badges grid

The recording is approximately 3 minutes long and shows the app on a real iPhone, not a simulator.

2. App purpose

Prisma Puzzles is a single-player iOS puzzle game that combines five distinct daily challenges into one calm, ad-free app. Each game uses a different cognitive skill — code-breaking (Signals), historic-date estimation (Archive), polyomino tiling (Cargo), letter-grid sliding (Shift), and signal routing through logic gates (Circuit). A fresh puzzle drops every midnight local time; the same puzzle is served to every user worldwide so they can compare scores with their Game Center friends.

The app is aimed at puzzle fans who want a short daily ritual — typically a few minutes per game — and value an offline-friendly, distraction-free experience with no ads, no tracking, and no in-app purchases. Each of the five games also ships with a 150-level local archive for players who want more than the daily puzzle.

3. Instructions for reviewing

No accounts, logins, or test credentials are required. The app has no auth flow at all. To review:

- On first launch, accept or dismiss the introductory how-to-play sheet
- Tap any game card on the Games tab to open that game
- Daily puzzles are accessible immediately; tap "Local levels" within any game to access the 150-level archive
- The Leaderboard tab will prompt for Game Center sign-in (system-level, handled by iOS); accept this prompt to view daily friend leaderboards and friend stats
- The "+" person icon at the top right of the Friends segment opens the native Game Center dashboard for adding friends
- The You tab shows the user's progress, streak counter, and earned badges

There are no paid features, no subscriptions, no in-app purchases, no advertising, no user-generated content, and no requests for access to camera, microphone, location, contacts, photos, or any other sensitive device capabilities or data.

4. External services, tools, and platforms

The app uses only Apple-provided services to deliver its core functionality:

- Apple Game Center — for leaderboards (`prisma.signals.daily.best`, `prisma.archive.daily.best`, `prisma.cargo.daily.best`, `prisma.shift.daily.best`, `prisma.circuit.daily.best`, `prisma.local.mastery`) and achievements (five "First-game" non-repeatable achievements: First Signal, First Archive, First Cargo, First Shift, First Circuit)
- Apple iCloud (NSPersistentCloudKitContainer) — for optional cross-device sync of the user's local game state, controlled by iOS-level iCloud settings

There are no third-party SDKs, no third-party authentication providers, no payment processors, no AI services, no data providers, no analytics services, and no tracking frameworks. The codebase is entirely Swift / SwiftUI / SwiftData / GameKit / CryptoKit, all first-party Apple frameworks.

5. Regional differences

The app functions identically in every region. Daily puzzle content is the same worldwide and is generated client-side from a deterministic seed based on the local date. There is no regional content gating, no region-specific feature flags, and no region-specific monetization. Localization is currently English (United Kingdom) only; we plan to add additional locales after launch but the app's behaviour is fully self-contained and identical across all regions in this release.

6. Regulated industry

Not applicable. Prisma Puzzles is a single-player puzzle game with no regulatory dimension — no health, finance, gambling, alcohol, dating, or any other regulated category.

Thank you. Please let us know if you need anything else to complete the review.
```

---

## Recording instructions — capture and attach

Apple is explicit that the recording must be **on a physical device**, not a simulator. Use whichever method is easier on the day:

### Method A — iOS Screen Recording (no Mac required)

1. iPhone: Settings → Control Center → scroll to "More Controls" → add **Screen Recording** if it isn't already in your Control Center.
2. Pull down Control Center (swipe from the top-right corner of the screen).
3. Long-press the record button (white circle inside a circle). A panel appears.
4. Make sure Microphone is **off** (unless you want to narrate).
5. Tap **Start Recording**. Wait 3 seconds. The status bar turns red.
6. Quit Control Center, return to the home screen, and **launch Prisma**.
7. Walk through the flow described in section 1 of the response above. Aim for 2–4 minutes total. Don't linger — show each game briefly (30–45 seconds each).
8. To stop: tap the red bar at the top of the screen → Stop. The video saves to Photos.
9. Open Photos → find the recording → Share → AirDrop to your Mac.

### Method B — QuickTime via USB (cleaner, requires Mac)

1. Connect iPhone to Mac via USB cable. Trust the computer if prompted.
2. Open QuickTime Player → File → **New Movie Recording**.
3. Click the dropdown next to the red record button → choose your iPhone as the camera source.
4. Click record. Walk through the flow on the iPhone (the screen mirrors live in QuickTime).
5. Stop. File → **Save** as `prisma_review.mov`.

Either method gives you a self-contained video file.

### Attaching to App Store Connect

In ASC, the Resolution Center accepts attachments up to **500 MB**. A 2–4 minute screen recording is typically 50–200 MB, well within limit. To attach:

1. ASC → My Apps → **Prisma Puzzles** → App Store tab → **1.0 Prepare for Submission** → top of page banner with the rejection message → **Reply**.
2. Paste the response text from above into the reply box.
3. Click the **paperclip icon** (or "Attach files") and upload the video.
4. Submit the reply.

If the file is too large to upload directly, alternative routes Apple accepts:

- Upload to a private YouTube link (Unlisted), paste the URL into the Notes field
- Upload to iCloud Drive and share a public link
- Use Vimeo with password protection

YouTube Unlisted is the simplest — no Apple account needed for the reviewer to view, no expiry, easy.

---

## After replying

Apple typically re-reviews within 24–48 hours of a Resolution Center reply. You can check status the same way:

```sh
asc review status --app 6762262232
```

The reply does not invalidate the build itself. Build 3 stays in the queue with the new context.

If they come back with a real issue (not just paperwork), paste the new message and we'll address it. The most common follow-up rejection is metadata-mismatch, which is a one-line fix.
