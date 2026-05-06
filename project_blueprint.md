# Prisma Project Blueprint (Current)

Last Updated: 2026-04-20

This blueprint describes the current architecture and delivery priorities. It supersedes older planning notes that assumed Supabase-backed profiles and a four-game roster.

---

## 1) Product Scope

Prisma is an iOS puzzle app organized around three user surfaces:

1. Daily puzzles.
2. Local archive progression.
3. Profile and stats.

Current live game roster in app navigation:

1. Signals
2. Archive
3. Cargo
4. Shift
5. Circuit

Note: An Orbit feature area exists in the repository, but Orbit is not currently part of the active GameType roster.

---

## 2) Platform and Stack

1. Platform target: iOS 18.0+ (with design aspirations for iOS 26 UX polish).
2. Language and UI: Swift 6, SwiftUI, Observation.
3. Persistence: SwiftData models (not Supabase-driven runtime persistence).
4. Social and ranking: GameKit leaderboards and achievements.
5. Architecture style: feature-oriented modules with game-specific view models and shared core services.

---

## 3) Core Architecture Principles

1. Offline-first gameplay:
	- Daily and local experiences must remain playable without network dependency.
	- Persistence should preserve in-progress and completed state where applicable.

2. Deterministic daily behavior:
	- Daily content generation/selection should be reproducible by date seed.
	- Completion and leaderboard submissions must remain consistent with recorded outcomes.

3. Shared progression contracts:
	- GameResult captures run outcomes/history.
	- LevelProgress captures local level completion state.
	- UI surfaces (selector, history, profile) must agree on score semantics per game.

4. Modern SwiftUI and concurrency:
	- Use current SwiftUI navigation/state patterns.
	- Favor async/await and actor-safe state mutation.

---

## 4) Circuit Blueprint (Current)

Circuit is now a first-class shipped mode and no longer a concept backlog item.

Current model:

1. Goal: satisfy all required target terminals and waypoints.
2. Gate set: NOT, Bridge, Synthesizer.
3. Color model: blue/red/yellow plus mixed outputs green/orange/purple.
4. Star model: completion baseline with optimization stars based on board coverage.

Current content pipeline:

1. Curated local level pack currently contains IDs 1...25.
2. Daily Circuit uses deterministic selection from curated content.
3. Canonical solution state is stored and replayed for history solution views.

Known active constraint:

1. Selector range is broader than currently authored Circuit archive depth, so level library expansion remains an active priority.

---

## 5) Validation and Quality Strategy

1. Automated tests:
	- Maintain focused game logic tests (especially Circuit runtime and serialization).
	- Add targeted regression tests whenever bugs are fixed in selector/history/replay behavior.

2. Content validation:
	- Keep script-based audits for level ID continuity and canonical solution integrity.
	- Re-run audits whenever transformed/generated level sets are changed.

3. Manual validation:
	- Verify daily completion -> history -> solution replay.
	- Verify local completion -> selector stars -> solution replay.
	- Verify give-up persistence and overlay behavior.

---

## 6) Current Delivery Priorities

1. Expand Circuit archive beyond the current 25 curated levels and keep progression coherent.
2. Harden Circuit tests by replacing placeholder cases with strict assertions.
3. Complete manual regression pass on daily/local/give-up flows after content and test updates.
4. Continue release polish tracks: audio/haptics, notifications, sync strategy, and App Store release preparation.