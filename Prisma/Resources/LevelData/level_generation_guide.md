# Level Generation Quick Reference Guide

## Using the Difficulty Progression

The `ShiftDifficultyProgression` struct provides all the formulas and parameters needed to generate levels that follow the designed difficulty curve.

## Quick Start

```swift
import Prisma

// Get parameters for any level
let params = ShiftDifficultyProgression.parameters(for: 50)
print(params.description)
// Output:
// Level 50 (intermediate)
// - Words: 4
// - Word Length: 4-6 letters
// - Optimal Moves: 10

// Use parameters to generate a puzzle
let wordCount = params.wordCount
let lengthRange = params.wordLengthRange
let targetMoves = params.optimalMoveCount
```

## Level Generation Workflow

### 1. Get Difficulty Parameters

```swift
let level = 42
let params = ShiftDifficultyProgression.parameters(for: level)
```

### 2. Generate Letter Grid

```swift
// Use letter frequency distribution (35-45% vowels)
let grid = generateLetterGrid(vowelPercentage: 0.40)
```

### 3. Select Target Words

```swift
// Find words matching the length range
let words = findWords(
    in: grid,
    count: params.wordCount,
    lengthRange: params.wordLengthRange
)
```

### 4. Scramble and Solve

```swift
// Scramble grid and compute optimal solution
let (scrambledGrid, optimalMoves) = scrambleAndSolve(
    grid: grid,
    targetWords: words
)
```

### 5. Validate Against Curve

```swift
let puzzle = ShiftPuzzle(
    id: level,
    initialGrid: scrambledGrid,
    targetWords: words,
    optimalMoveCount: optimalMoves
)

// Validate puzzle matches expected difficulty
let isValid = ShiftDifficultyProgression.validate(
    puzzle: puzzle,
    forLevel: level,
    moveTolerance: 2  // Allow ±2 moves from target
)

if !isValid {
    // Regenerate puzzle
}
```

## Tier-Specific Guidelines

### Beginner (Levels 1-20)

**Focus**: Teaching mechanics, building confidence

```swift
// Example Level 5
let params = ShiftDifficultyProgression.parameters(for: 5)
// Words: 2, Length: 3-4, Moves: 4

// Recommended words: CAT, DOG, SUN, HAT, PIG
// Place words in different rows
// Solutions should be discoverable in 1-2 attempts
```

**Design Tips:**
- Use common 3-letter words
- Avoid overlapping target words
- Keep solutions intuitive
- Introduce one concept per 5 levels

### Intermediate (Levels 21-60)

**Focus**: Building strategic thinking

```swift
// Example Level 35
let params = ShiftDifficultyProgression.parameters(for: 35)
// Words: 3, Length: 3-5, Moves: 8

// Recommended words: BIRD, FISH, TREE, STAR, MOON
// Some words may share rows (non-overlapping)
// Solutions require planning ahead
```

**Design Tips:**
- Mix 3-5 letter words
- Introduce word interdependencies
- Solutions require backtracking
- Multiple valid solution paths

### Advanced (Levels 61-85)

**Focus**: Challenging experienced players

```swift
// Example Level 75
let params = ShiftDifficultyProgression.parameters(for: 75)
// Words: 5, Length: 5-6, Moves: 14

// Recommended words: HOUSE, WATER, LIGHT, MUSIC, PLANT
// All 5 rows may have target words
// Tight constraints, minimal slack
```

**Design Tips:**
- Use 5-6 letter words
- Maximize grid utilization
- Require understanding of cycles
- Deep planning (8+ moves ahead)

### Expert (Levels 86-100)

**Focus**: Ultimate challenge

```swift
// Example Level 100
let params = ShiftDifficultyProgression.parameters(for: 100)
// Words: 5, Length: 6-7, Moves: 18

// Recommended words: GARDEN, WINDOW, BRIDGE, CASTLE, FOREST
// Highly constrained grids
// Solutions require mastery
```

**Design Tips:**
- Use 6-7 letter words
- Minimal letter frequency overlap
- Complex solution paths
- Final 5 levels are "boss puzzles"

## Validation Checklist

Before finalizing a level, verify:

- [ ] Word count matches tier requirements
- [ ] All word lengths within expected range
- [ ] Optimal move count within ±2 of target
- [ ] Puzzle is solvable (BFS finds solution)
- [ ] No overlapping words in same row
- [ ] All target word letters present in grid
- [ ] Vowel frequency 35-45%
- [ ] Rare letters (Q, X, Z) ≤ 1 per grid
- [ ] Optimal moves ≤ 25 (hard limit)

## Automated Validation

```swift
// Validate entire level set
for level in 1...100 {
    guard let puzzle = ShiftPuzzleLoader.loadLevel(level) else {
        print("❌ Level \(level) failed to load")
        continue
    }
    
    let isValid = ShiftDifficultyProgression.validate(
        puzzle: puzzle,
        forLevel: level
    )
    
    if !isValid {
        print("⚠️ Level \(level) does not match difficulty curve")
    }
}
```

## Printing Progression Table

```swift
// Print complete progression for reference
ShiftDifficultyProgression.printProgressionTable()
```

## Common Pitfalls

### ❌ Don't Do This

```swift
// Hardcoding word counts
let wordCount = 3  // Wrong! Use progression formula

// Ignoring tier boundaries
let words = generateWords(count: 4, forLevel: 15)  // Level 15 should have 2 words

// Skipping validation
let puzzle = generatePuzzle(level: 50)
// Save without validating - might not match curve!
```

### ✅ Do This Instead

```swift
// Use progression parameters
let params = ShiftDifficultyProgression.parameters(for: level)
let wordCount = params.wordCount

// Respect tier boundaries
let params = ShiftDifficultyProgression.parameters(for: 15)
let words = generateWords(count: params.wordCount, forLevel: 15)

// Always validate
let puzzle = generatePuzzle(level: 50)
if ShiftDifficultyProgression.validate(puzzle: puzzle, forLevel: 50) {
    savePuzzle(puzzle)
} else {
    regeneratePuzzle()
}
```

## Batch Generation

```swift
// Generate all 100 levels
func generateAllLevels() -> [ShiftPuzzle] {
    var puzzles: [ShiftPuzzle] = []
    
    for level in 1...100 {
        let params = ShiftDifficultyProgression.parameters(for: level)
        
        var attempts = 0
        var puzzle: ShiftPuzzle?
        
        // Try up to 10 times to generate valid puzzle
        while attempts < 10 {
            let candidate = generatePuzzle(
                level: level,
                wordCount: params.wordCount,
                lengthRange: params.wordLengthRange,
                targetMoves: params.optimalMoveCount
            )
            
            if ShiftDifficultyProgression.validate(
                puzzle: candidate,
                forLevel: level
            ) {
                puzzle = candidate
                break
            }
            
            attempts += 1
        }
        
        if let validPuzzle = puzzle {
            puzzles.append(validPuzzle)
            print("✅ Level \(level) generated successfully")
        } else {
            print("❌ Level \(level) failed after 10 attempts")
        }
    }
    
    return puzzles
}
```

## Testing Generated Levels

```swift
// Test a generated level
func testLevel(_ level: Int) {
    let params = ShiftDifficultyProgression.parameters(for: level)
    
    guard let puzzle = ShiftPuzzleLoader.loadLevel(level) else {
        XCTFail("Level \(level) failed to load")
        return
    }
    
    // Validate word count
    XCTAssertEqual(puzzle.targetWords.count, params.wordCount)
    
    // Validate word lengths
    for word in puzzle.targetWords {
        XCTAssertTrue(params.wordLengthRange.contains(word.word.count))
    }
    
    // Validate optimal moves (with tolerance)
    let moveRange = (params.optimalMoveCount - 2)...(params.optimalMoveCount + 2)
    XCTAssertTrue(moveRange.contains(puzzle.optimalMoveCount))
}
```

## References

- **Progression Curve**: `difficulty_progression.md`
- **Implementation**: `ShiftDifficultyProgression.swift`
- **Tests**: `ShiftDifficultyProgressionTests.swift`
- **Summary Table**: `progression_summary.txt`

---

**Last Updated**: 2024  
**Version**: 1.0
