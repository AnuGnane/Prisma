# Shift Level Data Format

This document describes the JSON format for Shift puzzle level data.

## Overview

Shift levels are defined in JSON files that specify the initial grid configuration, target words, and optimal solution length. The `ShiftLevelData` structure provides validation and conversion to runtime `ShiftPuzzle` instances.

## JSON Structure

### Top Level

The JSON file should contain an array of level objects:

```json
[
  {
    "levelId": 1,
    "initialGrid": [...],
    "targetWords": [...],
    "optimalMoves": 5
  },
  ...
]
```

### Level Object

Each level object has the following properties:

| Property | Type | Description | Constraints |
|----------|------|-------------|-------------|
| `levelId` | Integer | Unique identifier for the level | Positive integer (1-100 for local levels) |
| `initialGrid` | Array of Arrays | 5x5 grid of letters | Must be exactly 5 rows × 5 columns, each cell a single uppercase letter |
| `targetWords` | Array | Words that must be spelled | Array of TargetWordData objects (2-5 words recommended) |
| `optimalMoves` | Integer | Minimum moves to solve | Positive integer (typically 3-18) |

### TargetWordData Object

Each target word object has the following properties:

| Property | Type | Description | Constraints |
|----------|------|-------------|-------------|
| `word` | String | The word to spell | Uppercase letters, 3-7 characters recommended |
| `row` | Integer | Row index where word appears | 0-4 (0 = top row) |
| `startCol` | Integer | Starting column index | 0-4 (0 = leftmost column) |

## Example

```json
{
  "levelId": 1,
  "initialGrid": [
    ["C", "A", "T", "D", "E"],
    ["F", "G", "H", "I", "J"],
    ["K", "L", "M", "N", "O"],
    ["P", "Q", "R", "S", "T"],
    ["U", "V", "W", "X", "Y"]
  ],
  "targetWords": [
    {
      "word": "CAT",
      "row": 0,
      "startCol": 0
    }
  ],
  "optimalMoves": 5
}
```

## Validation Rules

The `toPuzzle()` method validates level data and returns `nil` if any validation fails:

### Grid Validation

1. **Row Count**: Must have exactly 5 rows
2. **Column Count**: Each row must have exactly 5 columns
3. **Cell Format**: Each cell must be a single character string
4. **No Empty Cells**: All cells must contain a character

### Target Word Validation

1. **Row Bounds**: `row` must be 0-4
2. **Column Bounds**: `startCol` must be 0-4
3. **Word Fits**: `startCol + word.length` must be ≤ 5
4. **No Negative Indices**: Both `row` and `startCol` must be non-negative

## Error Handling

When validation fails, the `toPuzzle()` method:
- Returns `nil`
- Logs a descriptive error message to the console
- Includes details about which validation rule failed

Example error messages:
```
❌ ShiftLevelData: Invalid grid row count - expected 5, got 4
❌ ShiftLevelData: Invalid grid column count - all rows must have 5 columns
❌ ShiftLevelData: Invalid grid cell - all cells must be single characters
❌ ShiftLevelData: Target word 0 has invalid row 5
❌ ShiftLevelData: Target word 1 'HELLO' extends beyond grid (startCol: 2, length: 5)
```

## Usage

### Loading from JSON

```swift
// Load JSON file
guard let url = Bundle.main.url(
    forResource: "shift_levels",
    withExtension: "json",
    subdirectory: "Resources/LevelData"
) else {
    print("❌ shift_levels.json not found")
    return
}

// Parse JSON
let data = try Data(contentsOf: url)
let decoder = JSONDecoder()
let levels = try decoder.decode([ShiftLevelData].self, from: data)

// Convert to puzzles
let puzzles = levels.compactMap { $0.toPuzzle() }
```

### Creating Level Data Programmatically

```swift
let levelData = ShiftLevelData(
    levelId: 1,
    initialGrid: [
        ["C", "A", "T", "D", "E"],
        ["F", "G", "H", "I", "J"],
        ["K", "L", "M", "N", "O"],
        ["P", "Q", "R", "S", "T"],
        ["U", "V", "W", "X", "Y"]
    ],
    targetWords: [
        TargetWordData(word: "CAT", row: 0, startCol: 0)
    ],
    optimalMoves: 5
)

if let puzzle = levelData.toPuzzle() {
    // Use puzzle
} else {
    // Handle validation error
}
```

## Best Practices

### Level Design

1. **Difficulty Progression**: Increase complexity gradually
   - Early levels: 2-3 words, 3-5 letters, 3-5 optimal moves
   - Mid levels: 3-4 words, 4-6 letters, 8-12 optimal moves
   - Late levels: 4-5 words, 5-7 letters, 12-18 optimal moves

2. **Letter Distribution**: Follow English language frequency
   - Vowels (A, E, I, O, U): 35-45% of grid
   - Common consonants (R, S, T, N, L): 40-50%
   - Rare letters (Q, X, Z): At most 1 per grid

3. **Word Selection**:
   - Use common, recognizable words
   - Avoid proper nouns and abbreviations
   - Ensure words don't overlap in the same row
   - Verify all target words can be spelled with available letters

4. **Optimal Move Count**:
   - Calculate using BFS solver
   - Should be achievable but challenging
   - Typically 20-40% of total possible moves

### Testing

Always test level data before deployment:

```swift
// Test loading
let levelData = // ... load from JSON
guard let puzzle = levelData.toPuzzle() else {
    XCTFail("Level data validation failed")
    return
}

// Test grid dimensions
XCTAssertEqual(puzzle.initialGrid.letters.count, 5)
XCTAssertTrue(puzzle.initialGrid.letters.allSatisfy { $0.count == 5 })

// Test target words
XCTAssertGreaterThanOrEqual(puzzle.targetWords.count, 2)
XCTAssertLessThanOrEqual(puzzle.targetWords.count, 5)

// Test optimal moves
XCTAssertGreaterThan(puzzle.optimalMoveCount, 0)
XCTAssertLessThanOrEqual(puzzle.optimalMoveCount, 25)
```

## File Location

Level data files should be placed in:
```
Prisma/Prisma/Resources/LevelData/shift_levels.json
```

This location is referenced by `ShiftPuzzleLoader` when loading levels.

## Related Files

- `ShiftLevelData.swift` - Data structure definitions
- `ShiftPuzzleLoader.swift` - Level loading logic
- `shift_levels.json` - Production level data (100 levels)
- `shift_levels_sample.json` - Sample level data for testing
