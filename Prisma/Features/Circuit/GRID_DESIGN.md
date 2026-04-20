# Circuit — Grid Design Rubric

Authoring guide for Circuit levels in `circuit_levels.json`. Covers the color model, gate semantics, win condition, the `solutionStateJSON` schema, and a checklist every new level must satisfy before shipping.

Audience: anyone adding or editing curated levels, or adjusting the daily generator. Pair this doc with `CircuitModels.swift` when anything below is ambiguous — the code is the source of truth.

## 1. Win condition

A level is won when every terminal pair's **target cell** is powered by a path whose final `PathSignal` has:

1. `color == targetCell.color` and
2. `signal == targetCell.signal`

The game evaluates this against the target *cell* (`CellState.target`), not against `TerminalPair.color`. Terminal-pair color metadata is used only for HUD/hints; a mismatch between `pair.color` and `targetCell.color` is a shipping bug (L6 and L10 previously had `pair.color = "blue"` with purple target cells — now fixed).

> Invariant: for every terminal pair, `pair.color == grid[pair.target.row][pair.target.col].color` and likewise for `signal`.

## 2. Color model

Six colors, three primaries and three secondaries:

| Color  | Kind      | Primary channels |
|--------|-----------|------------------|
| blue   | primary   | {blue}           |
| red    | primary   | {red}            |
| yellow | primary   | {yellow}         |
| purple | secondary | {blue, red}      |
| orange | secondary | {red, yellow}    |
| green  | secondary | {blue, yellow}   |

### Legal mixes (via `NeonColor.mixed(with:)`)

The mix is the channel-wise **union** of both operands' primary channels:

| `self`  | `other` | Result |
|---------|---------|--------|
| blue    | red     | purple |
| blue    | yellow  | green  |
| red     | yellow  | orange |
| X       | X       | X      |
| primary | matching-secondary (e.g. blue + purple) | that secondary |
| anything | tertiary-producing combo | **receiver (`self`)** — *unsupported, avoid* |

### Illegal mix (tertiary trap)

If the channel union resolves to `{blue, red, yellow}` the mix returns `self` unchanged — it does **not** produce a red/orange/etc. result. Concretely, the following combinations silently fail:

- green (blue+yellow) + red
- orange (red+yellow) + blue
- purple (blue+red) + yellow
- green + orange (or green + purple, or orange + purple) — any two secondaries that span all three channels
- blue + red + yellow in series through two synths

**Never design a level that requires a tertiary mix.** If the target color is a primary, every contributing input must already be that same primary, or the path must use a NOT-chain / secondary detour that does not unite all three channels at the synth. L16, L20, L21, L25 previously violated this rule and were redesigned to mix two distinct primaries into their intended secondary target.

## 3. Signal model

`SignalState` is orthogonal to color and binary: `active` or `inactive`. Sources emit a fixed signal; gates may transform it; targets require a specific signal to count as powered.

`PathSignal.wasTransformed` is set to `true` the first time a gate modifies the signal on a path — purely visual, not load-bearing for the win check.

## 4. Cell kinds

Stored as `CircuitCellData.kind` plus the matching optional fields.

### `.empty`

Passable, no effect. Default fill.

### `.source(color, signal)`

Origin of a path. Exactly one path per source; color/signal fields are required.

### `.target(color, signal)`

Destination. A path terminates here only if its final `PathSignal` matches both fields. Required fields as above.

### `.waypoint`

Passable, no effect on signal. Use sparingly — usually for path shaping / aesthetic routing.

### `.bridge`

Allows two paths to cross: one horizontal, one vertical. Each path passes through unchanged. A path may enter a bridge only in straight-line direction (no turning on a bridge). Using two paths through the same bridge is required by design for "bridge teaching" levels.

### `.notGate(direction:)`

Inverts `SignalState` (active ↔ inactive), color unchanged. `direction` is optional:

- `nil`: any direction traversal inverts.
- Set (e.g. `.topToBottom`): inversion only applies when the path enters-exit aligns with that direction. Wrong-direction traversal passes through unchanged — `wasTransformed` stays `false`.

Use directional NOT gates to force a specific routing — the canonical L25 capstone uses `.topToBottom` to force the blue path to descend through the gate, producing `blue/inactive`, which then XOR-combines with `red/active` at a downstream synth.

### `.synthesizer(logic, outputSignal)`

Two-input gate:

- `logic: .or` — emits `outputSignal` (usually `active`) iff **at least one** input is active.
- `logic: .xor` — emits `outputSignal` iff **exactly one** input is active.
- On output, the two input colors are merged via `NeonColor.mixed(with:)` (see §2).
- `outputSignal` is the signal-side boolean — set it to `active` unless you're deliberately teaching "two actives cancel" via XOR.

Partial state: if one input has arrived and the other has not, the synth is `partiallyFilled`; the first path visually stops at the synth. When the second input arrives, the merged output flows out of the synth along the second path's trailing direction.

## 5. `solutionStateJSON` schema

Each curated level carries a `solutionStateJSON` string that the game replays to validate the grid and to seed hints. Shape:

```json
{
  "activePaths": {
    "<colorKey>": {
      "sourceColor": "blue",
      "sourceSignal": "active",
      "segments": [{"row": 4, "col": 0}, ...],
      "currentSignal": {
        "color": "purple",
        "signal": "active",
        "wasTransformed": true
      },
      "isComplete": true
    },
    ...
  },
  "pathOrder": ["blue", "red"]
}
```

### Keys

- **Outer key** in `activePaths` is the **originating source color** (`sourceColor`). A synthesized path is keyed by its first contributor, not by its final mixed color.
- **`segments`** are the full cell trail in traversal order. First segment must be the source cell; last segment must be either the target cell (for a completing path) or the synth cell (for a partial contributor that stops at a synth).
- **`currentSignal`** describes the signal at the terminal segment — for a contributor stopping at a synth, this is the input signal (unchanged from source); for the path that traverses out of the synth, this is the mixed output.
- **`isComplete`** is `true` for any path that reaches its intended end-state. Partial contributors that stop at a synth still set `isComplete: true` in the canonical solution — they've reached their intended terminus.

### `pathOrder` — save-state fidelity

**Added to the model to fix the "random path rendering on restore" bug.** Swift's `Dictionary` does not preserve insertion order, so serializing `activePaths` alone loses draw order. With any synthesizer on the board, draw order is load-bearing: the first arrival becomes a partial input, the second triggers the mixed output. Swapping order produces a different — often non-winning — state.

Semantics:

- `pathOrder` is an optional array of color keys (matching `activePaths` outer keys) in the order the player (or canonical solution) drew them.
- On save, the ViewModel sets `pathOrder` to its `drawnColorOrder` array.
- On restore, the game replays paths verbatim in `pathOrder` — no permutation search needed.
- **Legacy saves** and curated `solutionStateJSON` without `pathOrder` (e.g. single-path levels) still work: the restore path falls back to a permutation search that only accepts a winning final state.
- **Ghost filtering**: if `pathOrder` lists a color with no matching entry in `activePaths`, that entry is silently dropped during decode (corruption tolerance).

Author rule: for any multi-path level that uses a synth or a bridge, `pathOrder` **must** be supplied in `solutionStateJSON`. Single-path or non-interacting multi-path levels may omit it.

## 6. Author checklist — before merging a new level

Run through every item. Anything unchecked = don't ship.

1. **Grid dimensions match size.** `grid.count == size` and every `row.count == size`.
2. **Every terminal pair resolves.** For each `pair`: the source cell at `pair.source` is a `.source` with matching `color`/`signal`; the target cell at `pair.target` is a `.target` with matching `color`/`signal`. (Enforced by `CircuitLevelLoaderTests.terminalPairColorMatchesTargetCell`.)
3. **Target color is reachable via legal mixes.** If the target is secondary (purple/orange/green), the contributing primaries must match §2's "Legal mixes" table. If the target is primary (blue/red/yellow), the path must deliver that primary without passing through a mix that combines all three channels (§2, tertiary trap).
4. **No NOT gate ambiguity.** If a level ships with a directional NOT, verify that the intended solution traverses in the inversion direction — otherwise the player will bounce off it and blame the level.
5. **Synth inputs cover both slots.** For every synthesizer, exactly two distinct paths must arrive at it. One-input levels should use a transform (NOT) or nothing at all, not a synth.
6. **Bridge has one horizontal + one vertical crosser.** Never two H's or two V's.
7. **`solutionStateJSON` replays to a winning state.** Run `CircuitLevelLoaderTests.allCuratedSolutionsReplayToSolvedState()` — if it fails, the solution is invalid.
8. **Multi-path synth/bridge levels include `pathOrder`.** Derive it by replaying the solution: the order inputs arrive at the synth **is** `pathOrder` (for two-contributor synths the first-arriving contributor must appear before the second-arriving in `pathOrder`).
9. **Path segments are grid-adjacent.** Every `segments[i+1]` differs from `segments[i]` by exactly one in row or column, not both (no diagonals).
10. **No self-intersecting paths.** A path may only revisit a cell if it's a bridge cell in the perpendicular axis.

Shipping levels that fail #3 or #7 is a common class of unwinnable-level bug. Every curated level ships with a test-enforced solution replay — the audit is cheap, run it.

## 7. Gate-teaching progression (curated level design heuristic)

The curated ladder should introduce concepts one at a time. Suggested ramp:

| Range   | New concept                                    |
|---------|------------------------------------------------|
| 1–5     | Source→target, single color, no gates          |
| 6–10    | Two terminal pairs, no interactions            |
| 11–13   | First NOT gate (unconstrained)                 |
| 14–15   | Directional NOT (teaches routing constraint)    |
| 16–18   | First synth (OR), primary+primary → secondary  |
| 19–20   | Synth + bridge crossing                        |
| 21–23   | Multiple synths, different mix targets         |
| 24–25   | Synth + NOT interplay (XOR capstone)           |

Anything that combines a new concept with a large grid (6×6+) before teaching it standalone is a learnability red flag. L25 intentionally combines XOR + directional NOT — it is a *capstone*, not an introduction.

## 8. Common traps

- **Tertiary mix trap** — green + orange at a synth does not produce red; it returns the receiver. See §2. This was the root cause of the L16/L20/L21/L25 unwinnability bug.
- **Dictionary-order save bug** — never serialize a multi-path save without `pathOrder`. The restore path used to rely on permutation search which only guaranteed winning replays; mid-game or give-up saves restored alphabetically, producing visually random grids.
- **Legacy color names** — older persisted states used `cyan`/`magenta`/`amber`/`violet`/`coral`. `NeonColor.init(legacyRawValue:)` handles these; `CircuitState.pathOrder` decode also routes through it. Don't introduce new legacy names — they compound the migration surface.
- **`pair.color` drift** — editing a target cell's color without updating the corresponding `TerminalPair.color` ships an unwinnable level that passes a naive visual scan. `terminalPairColorMatchesTargetCell()` catches this.
- **Synth partial rendering** — if the first-arriving path's endpoint is not the synth cell itself, restore will not re-establish the partial. Ensure the contributor's `segments` ends at the synth cell.

## 9. Related code

- `Models/CircuitModels.swift` — `NeonColor.mixed(with:)`, `SignalState`, `GateType`, `CircuitCellData`, `CircuitLevel`, `CircuitState`.
- `Models/CircuitStateSerializer.swift` — JSON wire format, `pathOrder` handling, legacy-color migration.
- `Models/CircuitLevel.swift` — `CircuitLevelLoader`, terminal-pair structures.
- `ViewModels/CircuitGameViewModel.swift` — `drawnColorOrder`, `restoreState(_:)`, `buildGameResult(...)`.
- `PrismaTests/CircuitGameTests.swift` — enforcement of rules in this doc.
- `Resources/circuit_levels.json` — the curated catalog.
