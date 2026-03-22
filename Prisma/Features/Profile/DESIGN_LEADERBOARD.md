# Prisma Leaderboard Architecture

This document outlines the proposed architectural foundation for adding competitive and social leaderboard features to Prisma, fulfilling tasks 8.1.1 through 8.1.4.

## 1. Data Model Schema (`TASK 8.1.1`)

The leaderboard requires a distributed model to store scores, ranks, and user metadata both locally and remotely.

### Proposed Models

```swift
@Model
class LeaderboardEntry {
    @Attribute(.unique) var id: UUID
    var gameTypeRaw: String
    var score: Int
    var dateAchieved: Date
    var playerID: String // Mapped to Game Center's player alias or a backend GUID
    var playerName: String
    var isVerified: Bool // False if played offline and pending sync
}

@Model
class PlayerProfile {
    @Attribute(.unique) var playerID: String
    var displayName: String
    var avatarURL: URL?
    var friendIDs: [String] // Array of IDs of accepted friends
}
```

The data schema relies heavily on segregating `LeaderboardEntry` by `gameTypeRaw`. Rather than storing the `GameResult`'s full JSON state, the leaderboard entry only posts metadata, date, and score to minimize bandwidth overhead.

## 2. Service Layer & Async Sync Patterns (`TASK 8.1.2`, `TASK 8.1.4`)

The architecture must support offline capabilities. Players should be able to complete a match on an airplane, and the app must silently sync that score to the global leaderboard when internet connectivity restores.

### Synchronous vs. Asynchronous Strategy
- **Local Fallback (SwiftData):** When a match finishes, a `GameResult` is inserted locally.
- **Background Sync Task:** A background `Task` (via `BGTaskScheduler` or an asynchronous coordinator on app launch) fetches any `GameResult` where `isSynced == false`.
- **Merging Conflicts:** Since scores are immutable once achieved, there are no structural merge conflicts. The remote service merely appends the new scores.

### Abstract Service Protocol

```swift
protocol LeaderboardSyncService: Sendable {
    func submitScore(_ score: Int, for gameType: GameType) async throws
    func fetchTopScores(limit: Int, for gameType: GameType) async throws -> [LeaderboardEntry]
    func fetchFriendsScores(for gameType: GameType) async throws -> [LeaderboardEntry]
}
```

By injecting `LeaderboardSyncService`, the app can mock these responses inside SwiftUI previews and Unit Tests (as pioneered in Phase 5 async tests).

## 3. Friend-Detection Strategy (`TASK 8.1.3`)

There are two primary ways to detect and connect friends in Prisma.

### Option A: Game Center (Recommended)
Prisma already possesses the `com.apple.developer.game-center` entitlement.
- **Workflow:** Utilize `GKLocalPlayer` and `GKLeaderboard`.
- **Pros:** Zero backend maintenance. Apple handles authentication, friend requests, COPPA compliance, and secure data storage. The "Friends Only" leaderboard is built natively into `GKLeaderboard`.
- **Cons:** Strictly limited to the Apple Ecosystem. Players cannot compete with friends on other platforms.

### Option B: Custom Backend (CloudKit + Public Database)
- **Workflow:** Build a custom friend-request system utilizing `CKRecord`.
- **Pros:** Full control over UI/UX. Can be extended to cross-platform using CloudKit Web Services.
- **Cons:** High engineering effort. Requires managing moderation, reporting mechanisms (App Store requirement), and complex async resolution.

**Decision Pending:** For Phase 9/v1.1, Option A (Game Center) is highly recommended for an indie utility to reduce operational overhead. Option B should only be considered if Prisma scales significantly or requires Android parity.
