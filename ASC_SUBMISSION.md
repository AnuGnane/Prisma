# App Store Connect — Submission Copy

Drafted 2026-04-25 for Prisma v1.0. Paste each block into the matching field on App Store Connect → Distribution → App Information / App Store Listing. Adjust before submitting; everything below is editable post-submission except the bundle ID itself.

---

## App name

`Prisma Puzzles`

(14 chars; max 30. Renamed from "Prisma - Daily Puzzles" 2026-04-26 because the bare "Prisma" is taken on the App Store. The shorter form pairs better with the subtitle and reads cleanly in App Store search.)

## Subtitle (max 30 chars)

**Recommended:** `Five daily puzzles, one app.`  *(29 chars)*

Alternatives if you want a different angle:
- `A daily ritual of five games.` *(29 chars)*
- `Sharpen your mind, every day.` *(30 chars)*
- `Five new puzzles every day.` *(27 chars)*

## Promotional text (max 170 chars)

Editable any time without re-submission, so use it for current events / themed content / new feature shouts.

**Recommended for launch:**

> Five distinct daily puzzles in one ritual: code-cracking, time-travelling, packing, sliding, and signal routing. Compare scores with friends on Game Center.

*(156 chars)*

## Description (max 4000 chars)

```
Five puzzles. One a day. A ritual you can finish before your coffee goes cold — or wrestle with for hours if you'd like.

Prisma combines five distinct daily challenges in a single calm, ad-free app. Each game flexes a different cognitive muscle, and a fresh puzzle drops every midnight — the same one for every player, so you can compare your performance with friends on Game Center.

THE FIVE GAMES

• Signals — Crack a four-digit code in as few guesses as possible. The classic logic puzzle, refined for daily play.

• Archive — A historic photograph drops every day. Guess the year it was taken; the closer you are, the better your score.

• Cargo — A grid, a pile of irregular pieces, and a tiling problem. Pack every cell to score a perfect clear.

• Shift — Slide rows and columns of letters until the target words appear. Fewer moves means a better score.

• Circuit — Route signals from sources to targets through logic gates. Solve at or under the par move count for a perfect mark.

ARCHIVES

Each of the five games ships with a 150-level local archive — handpicked, increasingly devious puzzles for when you want more than the daily. Progress is saved per level so you can quit anytime and resume later.

GAME CENTER

Sign in once and daily scores post automatically to your friends leaderboard. Earn first-win achievements by completing each game; track streaks and milestones with in-app badges. No accounts to create, no ads, no in-app purchases.

DESIGNED FOR FOCUS

Prisma is built for the iPhone you already have — clean light and dark themes, dynamic-type support, and a calm aesthetic that respects your time. Native SwiftUI, iOS 18 or later.

What's in your daily ritual?
```

*(approx. 1700 chars — leaves headroom for tweaks)*

## Keywords (max 100 chars, comma-separated)

Apple ranks the App Name, Subtitle, and your selected Categories automatically — no need to repeat words from those slots in the keyword field.

**Recommended:**

```
logic,word,mastermind,deduction,brain teaser,code,grid,connect,strategy,routing,minimal,ritual
```

*(91 chars; leaves 9 chars headroom)*

**Alternative if you want broader reach:**

```
puzzle,daily,logic,word,mastermind,brain teaser,code breaker,deduction,grid,routing,connect
```

*(91 chars — repeats "puzzle" and "daily" from the App Name, Apple guidance discourages this; included only as a fallback if the recommended set under-indexes after launch.)*

## Categories

- **Primary:** Games → Puzzle *(already set via `LSApplicationCategoryType = public.app-category.puzzle-games`)*
- **Secondary (optional):** Games → Word *or* Games → Strategy. If you have to pick one, **Word** matches Shift and Signals more closely than Strategy.

## Age Rating

Answer Apple's age-rating questionnaire on the same screen. Prisma should rate **4+** with all categories at "None" — there's no violence, no user-generated content, no alcohol/drug references, no gambling, no web content, no unrestricted social. Game Center is system-level so doesn't trigger a higher rating.

## Support URL (required)

Apple requires a URL where users can ask for help. Three low-effort options, in order of preference:

1. **GitHub Pages** — host the markdown content of `SUPPORT.md` (in this repo) at e.g. `https://anugnana.github.io/prisma-support/` or a similar path. Uses your existing GitHub account; one-time setup. Trivially editable.
2. **Notion public page** — paste the contents of `SUPPORT.md` into a Notion page, share publicly, paste the URL into ASC.
3. **A simple HTML page** anywhere stable (Cloudflare Pages, Netlify, your university web account if available).

Pick whichever is fastest. ASC re-accepts the URL on every submission, so changing it later is fine.

## Privacy Policy URL (required)

Same hosting options as the Support URL. Paste the contents of `PRIVACY.md` (in this repo) into the same hosting platform. Apple validates that the URL resolves; they don't review the policy content unless they see something suspicious.

You'll also need to fill out the **Privacy Nutrition Label** in ASC → Privacy. The good news: Prisma collects almost nothing.

| Question | Answer |
|---|---|
| Do you collect data? | **No** (data isn't collected by *you* — Game Center is operated by Apple and falls under Apple's privacy policy.) |
| Do you use tracking? | **No** |
| Linked to user? | N/A |
| Used for tracking? | N/A |

If ASC asks specifically about Game Center data: it's "Not Linked to You" because Apple manages that data on your behalf and you (the developer) receive only aggregated leaderboard entries.

## Marketing URL (optional)

Skip for first TestFlight. Can add later if you build a product page.

---

## Pre-submission checklist

Things to confirm before clicking "Submit for Review" once you go from TestFlight to App Store:

- [ ] Bundle ID `AG.Prisma` matches your ASC App Information record
- [ ] Privacy Policy URL is live and resolves
- [ ] Support URL is live and resolves
- [ ] AppIcon all slots filled (especially 1024×1024 marketing slot)
- [ ] AccentColor set for Light + Dark
- [ ] Three or more screenshots per device size (6.5" + 6.9" iPhone)
- [ ] Age rating questionnaire submitted
- [ ] "What to Test" pasted into TestFlight builds (see `TESTFLIGHT_NOTES.md`)
- [ ] Privacy Nutrition Label filled out
