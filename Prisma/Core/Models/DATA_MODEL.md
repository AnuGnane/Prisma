# Prisma Data Model Overview

Prisma utilizes `SwiftData` to handle persistence entirely locally with optional CloudKit sync scaffolding.

## Entities

### `GameResult`
Stores the outcome of every distinct game session.
- **Attributes:**
  - `id`: UUID
  - `gameTypeRaw`: String (Signals, Archive, Cargo, Shift)
  - `score`: Int
  - `date`: Date
  - `isDaily`: Bool
  - `durationSeconds`: Double
  - `levelId`: Int?
- **Relationship Serializations:**
  - Uses explicit JSON string representations instead of @Relationship to keep iCloud synchronization lightweight and to prevent heavy cascading deletion logic.
  - `cargoStateJSON`, `signalsStateJSON`, `archiveStateJSON`, `shiftStateJSON`.
  
### `LevelProgress`
Stores progression status for the offline level progression feature.
- **Attributes:**
  - `id`: UUID
  - `gameTypeRaw`: String
  - `levelId`: Int
  - `isPlayed`: Bool
  - `won`: Bool
  - `score`: Int
  - `guessesUsed`: Int
  - `playedDate`: Date
  - `durationSeconds`: Double

## Non-Persisted / Structural State

### `GameState` (Enum)
Represents the transient interaction session.
- `notStarted`, `inProgress`, `completed(score: Int)`, `failed`, `gaveUp`.

## Persistence Services

### `PersistenceManager`
- `fetchResult(for:on:context:)` queries standard matches.
- `fetchDailyResult(...)` separates Daily matches.
- `fetchAll(...)` aggregates for statistics (`WinRateChartView`).
- Ensures clean deletion of `.store`, `.shm`, `.wal` files if schema conflicts arise upon compilation update.
