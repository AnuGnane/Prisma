# Shift Game Difficulty Progression Curve

## Overview

This document defines the difficulty progression curve for all 100 levels of the Shift game. The curve ensures a smooth, engaging difficulty ramp that keeps players challenged without overwhelming them.

## Design Philosophy

The progression follows a **logarithmic curve** rather than linear scaling to:
- Provide gentle introduction for new players (levels 1-20)
- Build complexity steadily in mid-game (levels 21-70)
- Challenge experienced players in late-game (levels 71-100)
- Avoid sudden difficulty spikes that frustrate players

## Progression Parameters

### 1. Target Word Count (2 → 5 words)

Words are the primary complexity driver. More words mean more constraints to satisfy simultaneously.

**Progression Tiers:**
- **Levels 1-20**: 2 words (learning phase)
- **Levels 21-40**: 3 words (building confidence)
- **Levels 41-70**: 4 words (intermediate challenge)
- **Levels 71-100**: 5 words (expert challenge)

**Rationale**: Discrete jumps at tier boundaries create clear difficulty milestones. Players can feel their progress as they unlock new tiers.

### 2. Word Length (3-4 letters → 5-7 letters)

Longer words are harder to align and require more precise grid manipulation.

**Progression Formula:**
```
minLength = 3 + floor((level - 1) / 25)
maxLength = 4 + floor((level - 1) / 20)
```

**Progression Tiers:**
- **Levels 1-20**: 3-4 letters (short, easy to spot)
- **Levels 21-40**: 3-5 letters (mixed difficulty)
- **Levels 41-60**: 4-6 letters (medium words)
- **Levels 61-80**: 4-6 letters (consistent challenge)
- **Levels 81-100**: 5-7 letters (long, complex words)

**Rationale**: Gradual increase prevents sudden jumps. Mix of lengths within each tier adds variety.

### 3. Optimal Move Count (3-5 → 12-18 moves)

Move count determines puzzle complexity and solution depth. Higher counts require more strategic planning.

**Progression Formula:**
```
optimalMoves = 3 + floor((level - 1) * 0.15)
```

**Progression Curve:**
- **Levels 1-10**: 3-5 moves (immediate solutions)
- **Levels 11-30**: 5-8 moves (short planning)
- **Levels 31-50**: 8-11 moves (medium planning)
- **Levels 51-70**: 11-14 moves (strategic thinking)
- **Levels 71-90**: 14-17 moves (complex solutions)
- **Levels 91-100**: 17-18 moves (expert puzzles)

**Rationale**: Smooth logarithmic curve prevents difficulty walls. Cap at 18 moves prevents frustration.

## Detailed Level Breakdown

### Beginner Tier (Levels 1-20)
**Goal**: Teach mechanics, build confidence

| Level Range | Words | Word Length | Optimal Moves | Focus |
|-------------|-------|-------------|---------------|-------|
| 1-5         | 2     | 3-4         | 3-4           | Tutorial: single row/column slides |
| 6-10        | 2     | 3-4         | 4-5           | Basic combinations |
| 11-15       | 2     | 3-4         | 5-6           | Multi-step solutions |
| 16-20       | 2     | 3-4         | 6-7           | Planning ahead |

**Design Notes:**
- Use common 3-letter words (CAT, DOG, SUN, etc.)
- Target words should be in different rows to avoid confusion
- Solutions should be intuitive and discoverable
- Introduce one new concept per 5-level block

### Intermediate Tier (Levels 21-60)
**Goal**: Build strategic thinking, introduce complexity

| Level Range | Words | Word Length | Optimal Moves | Focus |
|-------------|-------|-------------|---------------|-------|
| 21-30       | 3     | 3-5         | 7-9           | Managing multiple constraints |
| 31-40       | 3     | 4-5         | 9-10          | Word interdependencies |
| 41-50       | 4     | 4-6         | 10-12         | Complex grid states |
| 51-60       | 4     | 4-6         | 12-13         | Advanced planning |

**Design Notes:**
- Introduce 4-5 letter words (BIRD, FISH, TREE, STAR)
- Some target words may share rows (non-overlapping)
- Solutions require backtracking and experimentation
- Optimal path not immediately obvious

### Advanced Tier (Levels 61-85)
**Goal**: Challenge experienced players, require mastery

| Level Range | Words | Word Length | Optimal Moves | Focus |
|-------------|-------|-------------|---------------|-------|
| 61-70       | 4     | 4-6         | 13-14         | Tight constraints |
| 71-80       | 5     | 5-6         | 14-16         | Maximum complexity |
| 81-85       | 5     | 5-7         | 16-17         | Expert patterns |

**Design Notes:**
- Use 5-6 letter words (HOUSE, WATER, LIGHT, MUSIC)
- All 5 rows may have target words
- Multiple valid solution paths with different move counts
- Require understanding of grid state cycles

### Expert Tier (Levels 86-100)
**Goal**: Ultimate challenge for dedicated players

| Level Range | Words | Word Length | Optimal Moves | Focus |
|-------------|-------|-------------|---------------|-------|
| 86-95       | 5     | 5-7         | 17-18         | Maximum difficulty |
| 96-100      | 5     | 6-7         | 18            | Showcase puzzles |

**Design Notes:**
- Use 6-7 letter words (GARDEN, WINDOW, BRIDGE, CASTLE)
- Highly constrained grids with minimal slack
- Solutions require deep planning (10+ moves ahead)
- Final 5 levels are "boss puzzles" - memorable challenges

## Difficulty Scaling Formula

For programmatic level generation, use these formulas:

### Word Count
```swift
func wordCount(for level: Int) -> Int {
    switch level {
    case 1...20: return 2
    case 21...40: return 3
    case 41...70: return 4
    case 71...100: return 5
    default: return 2
    }
}
```

### Word Length Range
```swift
func wordLengthRange(for level: Int) -> ClosedRange<Int> {
    let minLength = min(3 + (level - 1) / 25, 5)
    let maxLength = min(4 + (level - 1) / 20, 7)
    return minLength...maxLength
}
```

### Optimal Move Count
```swift
func optimalMoveCount(for level: Int) -> Int {
    let base = 3.0
    let growth = 0.15
    let calculated = base + Double(level - 1) * growth
    return min(Int(calculated.rounded()), 18)
}
```

## Validation Criteria

Each level must satisfy:

1. **Solvability**: Must have at least one solution path
2. **Move Count**: Optimal moves ≤ 25 (hard limit)
3. **Word Fit**: All target words fit within grid bounds
4. **No Overlap**: Target words in same row don't overlap
5. **Letter Availability**: All target word letters present in initial grid
6. **Difficulty Consistency**: Level N+1 should not be easier than level N

## Testing Strategy

### Automated Tests
- Verify all 100 levels load without errors
- Validate word counts match progression curve
- Validate word lengths fall within expected ranges
- Validate optimal move counts follow curve
- Verify no duplicate puzzles

### Manual Playtesting
- Play levels 1, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100
- Verify difficulty feels appropriate for tier
- Ensure no frustrating difficulty spikes
- Confirm solutions are discoverable

## Progression Visualization

```
Difficulty Curve (Optimal Moves)
18 |                                                    ████████████
17 |                                              ██████
16 |                                        ██████
15 |                                  ██████
14 |                            ██████
13 |                      ██████
12 |                ██████
11 |          ██████
10 |    ██████
 9 |  ████
 8 |████
 7 |███
 6 |██
 5 |██
 4 |█
 3 |█
   +----------------------------------------------------------------
   1    10    20    30    40    50    60    70    80    90    100
                              Level Number

Word Count Progression
5 |                                                    ████████████
4 |                              ██████████████████████
3 |          ████████████████████
2 |██████████
  +----------------------------------------------------------------
  1    10    20    30    40    50    60    70    80    90    100
                            Level Number
```

## Implementation Notes

### For Level Authors
1. Start with the progression formulas above
2. Generate initial grid with proper letter frequency
3. Select target words matching length requirements
4. Use BFS solver to compute optimal move count
5. Adjust grid if optimal moves don't match target
6. Validate puzzle meets all criteria
7. Playtest to ensure fun and fair

### For Automated Generation
1. Use seeded RNG for reproducibility
2. Generate letter grid with vowel frequency 35-45%
3. Find all possible words in grid matching length range
4. Select non-overlapping words up to target count
5. Scramble grid with random moves
6. Compute optimal solution with BFS
7. Retry if optimal moves outside target range (±2 moves tolerance)
8. Maximum 10 retry attempts before moving to next level

## Difficulty Adjustment Guidelines

If playtesting reveals issues:

**Too Easy:**
- Increase optimal move count by 1-2
- Add one more target word (if under tier maximum)
- Use longer words within tier range
- Reduce letter frequency overlap with target words

**Too Hard:**
- Decrease optimal move count by 1-2
- Remove one target word (if above tier minimum)
- Use shorter words within tier range
- Increase letter frequency overlap with target words

**Inconsistent:**
- Smooth out move count jumps between adjacent levels
- Ensure word count changes happen at tier boundaries
- Verify no sudden word length jumps

## References

- Requirements: 12.1, 12.2, 12.3, 12.4, 12.5
- Design Document: Section on Difficulty Scaling
- Level Format: SHIFT_LEVEL_FORMAT.md
- Puzzle Generator: ShiftPuzzleGenerator.swift

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Status**: Ready for Implementation
