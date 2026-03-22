# Prisma Multi-Game Expansion Template

This document outlines the architectural patterns and requirements for adding a new game to the Prisma catalog, fulfilling tasks 8.2.1, 8.2.3, and 8.2.4.

## 1. Feature Folder Template (`TASK 8.2.1`)

All new games must follow the established MVP architecture structured in `Features/`:

```text
Features/[GameName]/
├── Models/
│   ├── [GameName]State.swift      // The core model for the game board
│   ├── [GameName]Level.swift      // Progression configuration constraints
│   └── [GameName]Generator.swift  // Logic to build permutations (if procedurally generated)
├── ViewModels/
│   └── [GameName]ViewModel.swift  // @Observable Game Engine; tracks time, moves, win/loss
└── Views/
    ├── [GameName]GameView.swift   // The primary Interactive Container
    ├── [GameName]BoardView.swift  // Just the Grid or interactive elements
    ├── [GameName]InputView.swift  // Keyboard/Inputs (reusable)
    └── Helpers/
        └── [GameName]Theme.swift  // Colors and geometry specific to this game
```

## 2. Shared UI Components (`TASK 8.2.4`)

New games should drastically reduce boilerplate by adopting the universal primitives residing in `Core/Views/`:

- `GameHeaderView.swift`: Standard back button, timer/score, and level title.
- `LevelCompleteOverlay.swift`: Standard "You Win!" / "You Lose!" modal sharing statistics and Action Buttons.
- `DailyCalendarView.swift`: A native, reusable calendar interface if the game supports daily challenges.
- `ConfettiView.swift`: High-performance, cancellation-safe particle emitter.

### Design System Compliance
- **Colors:** Use Semantic Colors (`.accentColor`, `.secondary`, `.background`) and define specific palette overrides in the game's Theme helper rather than hardcoding HEX colors inline.
- **Typography:** Ensure `Dynamic Type` is supported organically using standard `Font.xxx` accessors (e.g., `.title`, `.body`) without arbitrary fixed `frame()` or `.font(.system(size: 20))`.

## 3. Data Migration and Expansion Strategy (`TASK 8.2.3`)

### 1. Extensible `GameType` 
The `GameType` enum in `Core/Models/GameType.swift` natively supports expansion:
```swift
enum GameType: String, Codable, CaseIterable {
    case signals
    case archive
    case cargo
    case shift
    case [newGame] // Expand here
}
```

### 2. Migration Path
Because `GameResult` uses `gameTypeRaw: String` under the hood for SwiftData persistence, *adding* a new case strictly operates as a schema append. Older versions of the app will ignore unknown raw value strings if a user downgrades/syncs across devices running older OS versions. 

**Steps to integrate:**
1. Register `case newGame` in `GameType`.
2. Append a new serialized state JSON attribute to `GameResult` to store its exact playback sequence (e.g., `newGameStateJSON: String?`).
3. Add a new switch case across the `Profile/` feature (e.g., `WinRateChartView` and `Badges`) to recognize the new statistics. No complex multi-version schema `.custom` SwiftData `SchemaMigrationPlan` is necessary for plain appends if the new properties are optional!
