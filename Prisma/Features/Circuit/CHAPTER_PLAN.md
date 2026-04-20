# Circuit — 100-Level Chapter Plan

The catalog is organized into 5 chapters of 20 levels each. Each chapter introduces one core concept and finishes with a 2-3 level stretch that fuses it with prior mechanics. Grid sizes scale across the run (4×4 → 7×7). All new levels ship with a valid `solutionStateJSON` and `pathOrder` so `allCuratedSolutionsReplayToSolvedState()` protects the whole catalog.

The plan retires the old flat 1-25 set and reauthors the catalog. This is cleaner than surgery on the existing levels and gives us a consistent difficulty curve.

## Gate vocabulary after this wave

| Gate      | Role                                                    | Icon (SF Symbol)          |
|-----------|---------------------------------------------------------|---------------------------|
| Spark     | Inactive → Active, no-op on already-active (NEW)        | `bolt.fill`               |
| Inverter  | Bidirectional invert (active ↔ inactive). Renamed NOT.  | `arrow.triangle.2.circlepath` |
| Bridge    | Two paths cross without mixing                          | `arrow.triangle.branch`   |
| Synth OR  | Two inputs → merged output when either is active        | `arrow.triangle.merge`    |
| Synth XOR | Output active iff exactly one input is active           | `arrow.triangle.merge` + `xmark` badge |
| Waypoint  | Must-visit, no signal transform                         | crosshair                 |

## Chapter 1 — Sparks (L1-L20)

Teach the core drawing loop, terminal matching, and the new Spark gate.

Grid sizes: **4×4 → 5×5**
Signal palette: **active** only (for L1-L6), **inactive-target** introduced at L7 to motivate Spark.

| # Range | Concept | Example |
|---------|---------|---------|
| 1-3   | Single source → target, one color. Just drawing. | 4×4 blue `active` corner-to-corner |
| 4-6   | Two independent color pairs, no crossing required. | 4×4 blue + red, diagonally placed |
| 7-10  | Spark introduction. Source emits `inactive`, target wants `active`, Spark in the middle must be traversed. | 5×5 single yellow source `inactive` → target `active` via Spark |
| 11-15 | Two pairs, one requires Spark. Teaches choosing which path goes through the gate. | 5×5 blue direct + yellow-through-Spark |
| 16-18 | Spark + waypoint — forced routing through the gate. | 5×5 waypoint gating access to the Spark |
| 19-20 | Two Sparks, two sources. Both colors must energize. | 5×5 with parallel Spark paths |

## Chapter 2 — Crossings (L21-L40)

Bridges, and the routing discipline they demand.

Grid sizes: **5×5 → 6×6**

| # Range | Concept |
|---------|---------|
| 21-24 | Bridge introduction — two colors must cross at the bridge. |
| 25-28 | Bridge + Spark — one of the crossing lines also gets energized. |
| 29-34 | Multi-bridge levels (two bridges on different axes). |
| 35-38 | Bridge + Waypoint — bridge access gated by must-visit cells. |
| 39-40 | Bridge + Spark + Waypoint compounds. |

## Chapter 3 — Synthesis (L41-L60)

Synthesizer (OR), mixing primaries into secondary-target wins.

Grid sizes: **5×5 → 6×6**

| # Range | Concept |
|---------|---------|
| 41-44 | First synth. blue+red → purple. Two sources, one target. |
| 45-48 | All three primary pair mixes (orange, green, purple) introduced. |
| 49-52 | Synth + Spark — one of the contributing sources is `inactive` and must be Sparked before entering the synth. |
| 53-56 | Synth + Bridge — an incoming contributor crosses another path via bridge on the way to the synth. |
| 57-60 | Multi-synth (two stages) — the output of one synth feeds into the input of another. Primary → secondary → secondary cascading is safe because the color union stays inside two primary channels. |

## Chapter 4 — Inversion (L61-L80)

Inverter (renamed NOT), for when `active → inactive` is required. Paired with Spark for the inverse case so players build a mental model of both tools.

Grid sizes: **5×5 → 7×7**

| # Range | Concept |
|---------|---------|
| 61-64 | Inverter introduction — source `active`, target `inactive`. |
| 65-68 | Directional Inverter — constrained gate, wrong direction passes through. |
| 69-72 | Inverter + Spark on different paths (one line turns off, another turns on). |
| 73-76 | Inverter + Synth — reach an `inactive` secondary target via inverted primary input. |
| 77-80 | Inverter + Synth + Bridge compounds. |

## Chapter 5 — Capstones (L81-L100)

The novel XOR synth mechanic, plus full-board puzzles that remix everything.

Grid sizes: **6×6 → 7×7**

| # Range | Concept |
|---------|---------|
| 81-84 | XOR synth introduction — two active inputs cancel to inactive, exactly-one-active wins. |
| 85-88 | XOR + Inverter — the classic L25 pattern generalized (one input deliberately inverted before the XOR). |
| 89-92 | XOR + Spark — one input is `inactive`, becomes `active` via Spark en route to XOR. |
| 93-96 | "Everything" levels — bridge + synth + Inverter + Spark in the same grid. |
| 97-100 | Boss puzzles — 7×7, 3 terminal pairs, multiple synths. L100 is the final capstone. |

## Design invariants (every level must satisfy)

1. All `TerminalPair.color`/`signal` match their target cell (GRID_DESIGN §6.2).
2. Synth targets are reachable via a legal primary+primary mix (never a tertiary mix; GRID_DESIGN §2).
3. `solutionStateJSON` replays to a winning state with the supplied `pathOrder`.
4. At least one path segment passes through every gate placed on the grid (no ornamental gates).
5. Solution path length is ≥ size+1 for that grid size (no 3-cell solutions on a 5×5).

## Migration

- Old IDs 1-25 will be replaced in `circuit_levels.json`.
- Daily-level IDs are negative, so player progress on daily runs is not affected.
- Player progress on local levels will snap to the nearest chapter of the new catalog (see `FIX_PLAN.md` for the migration table once levels are generated).

## Authoring plan

- A parameterized Python builder (`scratch/build_catalog.py`) defines seed designs per chapter (8-12 seeds each) and applies variations (grid size nudges, source/target swaps, mirror/rotate transforms) to reach 20 per chapter.
- Each generated level has its solution path derived during generation, then serialized with `pathOrder`.
- Audit: `allCuratedSolutionsReplayToSolvedState()` runs against the full 100-level catalog.
