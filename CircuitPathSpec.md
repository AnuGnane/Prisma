# Circuit — Path Rendering Specification
## All Scenarios & Edge Cases

### 1. Data Model

| Object | Role |
|--------|------|
| `ActivePath.segments` | Ordered list of `GridPosition` from source terminal to draw head |
| `ActivePath.sourceColor` | The NeonColor this path originated from (never changes) |
| `ActivePath.sourceSignal` | The SignalState emitted by the source terminal (never changes) |
| `ActivePath.currentSignal` | The **evolved** signal at the draw head — changes when gates are passed |
| `pathLayer[pos]` | Per-position signal map. **Source terminals are never added here by design.** Gate cells may or may not be added depending on VM behaviour. |

### 2. Signal Lookup — `signalAt(index:in:)`

**Rule**: When `pathLayer[pos]` is nil, fall back to `PathSignal(color: sourceColor, signal: sourceSignal)`.

**Why not `currentSignal`**: `currentSignal` is the post-gate evolved signal. Using it as a
fallback for any position not in pathLayer (especially index 0 = source terminal) causes a
spurious run transition between the source cell and the first drawn cell. This generates a
single-cell `Run[0,0]` that fails `endIndex > startIndex` and is silently skipped — making the
source-to-gate section completely invisible.

### 3. Run Grouping — `buildSegmentRuns`

A **run** is a maximal contiguous slice of path segments with identical `(color, signalState)`.

**Transition rule**: When a signal change is detected at index `i`, the new run starts at `i`
(the gate cell itself), NOT at `i - 1`. The previous run extends its tail in `buildStubPath`.

**Guard**: Runs with `endIndex == startIndex` are skipped (cannot draw a line from one point).
This is safe because the source terminal at index 0 is now grouped with cell-1 via the
`sourceSignal` fallback, producing a multi-cell run.

### 4. Stub Drawing — `buildStubPath`

For each segment in the run:

| Segment type | Action |
|--------------|--------|
| Normal cell, pen up | `move(to: cellCenter)` |
| Normal cell, pen down | `addLine(to: cellCenter)` |
| Normal cell, previous was gate, pen up | `move(to: exitPort)` then `addLine(to: cellCenter)` |
| Gate cell, first in run | pen stays up (no entry stub — run starts here) |
| Gate cell, not first in run | draw entry stub to `portPoint(gate, facing: prevCell)`, then lift pen |

**Tail extension**: after the main loop, if the pen is down AND the next index is a gate, extend
the current sub-path to `portPoint(gate, facing: lastCell)`. This ensures the run's wire reaches
the gate's visual border without a gap.

### 5. Port Point Geometry

```
Cell edge:        0.50 × cellSize from gate centre
portPoint:        0.42 × cellSize from gate centre (path stub terminates here)
Gate bg border:   0.39 × cellSize from gate centre
Gate icon zone:   0.00–0.30 × cellSize from gate centre
```

The round stroke cap (radius = 0.12 × cellSize) extends from portPoint toward the gate centre,
reaching 0.30 × cellSize — well inside the gate background. The gate's **opaque dark base layer**
(in `GateCellView`) masks this cap entirely. The **edge connector** bridges from the gate border
(0.39) to the cell edge (0.50) in the signal colour.

### 6. Scenarios

#### 6a. Straight pass-through (no signal change)
- Path: `[src, A, B, gate, C, D, target]`
- Single run, same signal throughout
- buildStubPath: `src→A→B→portPoint(entry)` [pen up] → `exitPort→C→D→...`
- Gate: two edge connectors (entry + exit), matching colour, tinted bg + border glow

#### 6b. Signal transformation at gate (e.g. NOT gate inverts inactive→active)
- Path: `[src, A, B, gate, C, D, target]`
- Run 1: `[0..2]` — inactive signal (dim 58% core), wire from `src→A→B→portPoint(entry)`
- Run 2: `[3..end]` — active signal (100% core), wire from `exitPort→C→D→...`
- Gate: entry connector = incoming colour, exit connector = outgoing colour
- Both connectors shown; gate bg/border tinted to OUTPUT colour

#### 6c. Path head currently AT the gate
- Gate is the last segment; next index doesn't exist
- Entry edge connector shown (from prev cell direction), exit connector NOT shown
- Gate tinted to incoming signal (ViewModel reports gate state as partially traversed)

#### 6d. Source terminal (never in pathLayer)
- `signalAt(0)` → `PathSignal(sourceColor, sourceSignal)` (NOT `currentSignal`)
- Source cell grouped into the same run as cells 1, 2, … (pre-gate cells share sourceSignal)
- Wire drawn from source centre through pre-gate cells to gate portPoint

#### 6e. Bridge gate (two paths cross)
- Each path independently contributes stubs stopping at the bridge's portPoints
- `activeEdgesForGate` iterates ALL active paths — up to 4 edge connectors lit
- Gate state `.bridgeLocked`: cyan border, cyan bg tint
- Horizontal path connectors: leading + trailing; vertical: top + bottom

#### 6f. Single-segment path (tap but no drag)
- `path.segments.count == 1` → special case in `drawPath`, draws a start dot only
- No runs computed

#### 6g. Inactive path (dim rendering)
- Ambient: 3%, Bloom: 22%, Core: 65%
- Clearly readable as "a path, just unlit" on the dark board
- Solved-inactive (path complete but target needs inactive): same brightness as active

#### 6h. Directional NOT gate — path enters from non-triggering direction
- Signal passes through UNCHANGED
- Single run, no colour break at gate
- Gate in `.idle` state (or `.active` if it passes through without triggering)
- Edge connectors both drawn in the unchanged signal colour

#### 6i. Synthesizer gate (two inputs → combined output)
- Two paths each approach from different sides
- State `.partiallyFilled`: one input present, dots shown below gate
- State `.active(outputColor)`: combined signal output; exit connector in output colour

#### 6j. Consecutive gates (gate immediately adjacent to another gate)
- Run starting at gate1: gate1 is first (no entry stub), gate2 is next
- For gate2: `i > startIndex` → draw stub from gate1's portPoint to gate2's portPoint
  (`move(to: portPoint(gate2, facing: gate1))`, then `penIsUp = true` for gate2)
- Result: a tiny sub-path connecting the two gate borders in the run's colour
- Both gates show edge connectors on their shared side

### 7. Three-Pass Rendering Parameters

| Pass | Width | Active opacity | Inactive opacity |
|------|-------|----------------|------------------|
| Ambient halo | 0.46 × cellSize | 8% | 3% |
| Bloom | 0.34 × cellSize | 30% | 22% |
| Core | 0.24 × cellSize | 100% | 65% |

### 8. Gate Visual Layers (GateCellView)

1. Outer glow halo — `blur` on bg rect (only when active)
2. **Opaque dark base** — `Color(red:0.06, green:0.06, blue:0.10)` — masks Canvas round cap
3. Signal colour tint — translucent (20% active, type-specific 7–9% idle)
4. Border ring — 0.044 × size lineWidth, signal colour 85% active, type-specific 28% idle
5. Gate icon — type-specific identity colour (orange/yellow/cyan/purple)
6. Edge connectors — 0.24 × size cross-section, signal colour + shadow glow, per active edge
7. Preview badge / synth partial indicator overlay
