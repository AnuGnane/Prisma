//
//  FriendsService.swift
//  Prisma
//
//  @Observable singleton that owns the Game Center friends social layer:
//    • loadFriendsAuthorizationStatus state machine (iOS 14.5+ explicit permission flow)
//    • Caches [GKPlayer] friend list, refreshed on demand
//    • Batched leaderboard queries for today-summaries (5 leaderboards, concurrent)
//    • Per-friend profile + head-to-head stats for FriendProfileView
//
//  Rate-limit note: today-summary results are cached for 30 s. Pulling to refresh
//  before the cache expires is a no-op to avoid hammering GK servers.
//
//  Phase 2 (2026-04-25): streak leaderboards no longer queried — they stay
//  unconfigured in ASC per LEADERBOARD_RESTRUCTURE_PLAN.md §2. We only read
//  the `daily.best` boards now.
//

import GameKit
import Observation

@Observable @MainActor
final class FriendsService {

    static let shared = FriendsService()

    // MARK: - Auth State

    enum FriendsAuthState: Equatable {
        case unknown
        case notDetermined   // can request permission
        case authorized      // loadFriends will succeed
        case denied          // user declined — direct to Settings
        case restricted      // parental controls etc.
    }

    private(set) var authState: FriendsAuthState = .unknown

    // MARK: - Friends + Summaries

    private(set) var friends: [GKPlayer] = []
    private(set) var summaries: [String: FriendTodaySummary] = [:]  // keyed by gamePlayerID
    private(set) var isLoadingFriends    = false
    private(set) var isLoadingSummaries  = false
    private(set) var friendsError: String?

    // MARK: - Cache

    private var summaryCachedAt: Date?
    private let summaryCacheTTL: TimeInterval = 30  // seconds — lower for more responsive friend updates

    /// Invalidates the summary cache so the next `loadTodaySummaries()` call
    /// fetches fresh data from Game Center. Call this after submitting a new
    /// score so the local player's own game icons update promptly.
    func invalidateCache() {
        summaryCachedAt = nil
    }

    // MARK: - Computed

    /// Friends sorted per spec: active-today first (gamesSolvedToday desc),
    /// then not-played-today (alphabetical).
    var sortedFriends: [GKPlayer] {
        friends.sorted { a, b in
            let sa = summaries[a.gamePlayerID]
            let sb = summaries[b.gamePlayerID]
            let aPlayed = sa?.hasSolvedToday ?? false
            let bPlayed = sb?.hasSolvedToday ?? false

            // Tier 1: played today sinks above those who haven't
            if aPlayed != bPlayed { return aPlayed }

            // Tier 2 (both played today): games solved desc
            let aGames = sa?.gamesSolvedToday ?? 0
            let bGames = sb?.gamesSolvedToday ?? 0
            if aGames != bGames { return aGames > bGames }

            // Tier 3: alphabetical
            return a.displayName < b.displayName
        }
    }

    // MARK: - Authorization

    /// Checks the current friends-authorization status without requesting permission.
    func checkAuthorizationStatus() async {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        do {
            let status = try await GKLocalPlayer.local.loadFriendsAuthorizationStatus()
            authState = mapAuthStatus(status)
        } catch {
            authState = .unknown
            #if DEBUG
            print("[FriendsService] loadFriendsAuthorizationStatus error: \(error)")
            #endif
        }
    }

    // MARK: - Load Friends

    /// Loads (or reloads) the friend list. Calling this when status is .notDetermined
    /// will trigger the iOS system permission sheet automatically.
    func loadFriends() async {
        guard GKLocalPlayer.local.isAuthenticated else {
            authState = .unknown
            return
        }

        isLoadingFriends = true
        friendsError = nil
        defer { isLoadingFriends = false }

        do {
            // loadFriends triggers the permission sheet if status is .notDetermined
            let loaded = try await GKLocalPlayer.local.loadFriends()
            friends = loaded

            // Update auth state based on the fact that loading succeeded
            authState = .authorized

            // Immediately load today summaries for the freshly-loaded list
            await loadTodaySummaries(force: true)
        } catch let gcError as GKError where gcError.code == .notAuthorized {
            authState = .denied
            #if DEBUG
            print("[FriendsService] Friends access denied")
            #endif
        } catch {
            authState = .unknown
            friendsError = "Couldn't load friends. Check your connection."
            #if DEBUG
            print("[FriendsService] loadFriends error: \(error)")
            #endif
        }
    }

    // MARK: - Today Summaries (batched)

    /// Loads today-scope summaries for all friends across all 5 games.
    /// Results are cached for `summaryCacheTTL` (30 s); pass `force: true` to bypass the cache.
    func loadTodaySummaries(force: Bool = false) async {
        guard !friends.isEmpty else { return }

        // Cache check — also invalidate if the cached data is from a previous
        // calendar day, since `.today` scope entries would be stale.
        if !force, let cachedAt = summaryCachedAt,
           Date().timeIntervalSince(cachedAt) < summaryCacheTTL,
           Calendar.current.isDate(cachedAt, inSameDayAs: Date()) {
            return
        }

        isLoadingSummaries = true
        defer { isLoadingSummaries = false }

        struct LeaderboardResult: @unchecked Sendable {
            let game: GameType
            /// Entries keyed by friend `displayName` — the only identifier
            /// that's guaranteed consistent between `loadFriends()` and
            /// leaderboard entry players across all GC account contexts.
            let entries: [(displayName: String, score: Int, rank: Int)]
        }

        var results: [LeaderboardResult] = []

        // Step 1: BATCH-load all 5 leaderboards in a single call.
        //
        // Critical: do NOT split this into per-game `loadLeaderboards(IDs:)`
        // calls inside the TaskGroup below. A previous attempt did exactly
        // that and Game Center returned empty arrays for every game (logged
        // as "No board found …"), almost certainly due to GameKit's internal
        // rate-limiting on concurrent loadLeaderboards calls. Batched, this
        // is one network round trip and reliably returns all 5 boards.
        let allIDs = GameType.allCases.map { bestLeaderboardID($0) }
        let allBoards: [GKLeaderboard]
        do {
            allBoards = try await GKLeaderboard.loadLeaderboards(IDs: allIDs)
        } catch {
            #if DEBUG
            print("[FriendsService] batch loadLeaderboards failed: \(error.localizedDescription)")
            #endif
            summaries = [:]
            summaryCachedAt = Date()
            return
        }

        // Build lookup keyed by `baseLeaderboardID`. This is the recurring-
        // leaderboard family identifier (e.g. `prisma.signals.daily.best`),
        // matching what we passed into loadLeaderboards. The previous "batch
        // mismatch" concern was unfounded — Apple consistently sets
        // baseLeaderboardID to the input ID for non-recurring boards.
        let boardByID = Dictionary(
            uniqueKeysWithValues: allBoards.map { ($0.baseLeaderboardID, $0) }
        )

        #if DEBUG
        print("[FriendsService] Loaded \(allBoards.count) of \(allIDs.count) boards. IDs: \(boardByID.keys.sorted())")
        #endif

        // Step 2: Use player-specific queries (loadEntries(for: [GKPlayer]))
        // instead of .friendsOnly scope. The .friendsOnly scope returns player
        // objects whose gamePlayerID/teamPlayerID don't match the IDs from
        // loadFriends() — causing silent 0/5 on some accounts. Passing the
        // actual GKPlayer objects from loadFriends() avoids that.
        let friendsCopy = friends  // capture for Sendable closure
        await withTaskGroup(of: LeaderboardResult?.self) { group in
            for game in GameType.allCases {
                let leaderboardID = bestLeaderboardID(game)
                guard let board = boardByID[leaderboardID] else {
                    #if DEBUG
                    print("[FriendsService] Board missing from batch result for \(game.rawValue) (ID: \(leaderboardID))")
                    #endif
                    continue
                }
                group.addTask { [friendsCopy, board] in
                    do {
                        let (_, entries) = try await board.loadEntries(
                            for: friendsCopy,
                            timeScope: .today
                        )

                        #if DEBUG
                        print("[FriendsService] \(game.rawValue): \(entries.count) friend entries today")
                        #endif
                        return LeaderboardResult(
                            game: game,
                            entries: entries.map {
                                ($0.player.displayName, $0.score, Int($0.rank))
                            }
                        )
                    } catch {
                        #if DEBUG
                        print("[FriendsService] \(game.rawValue) loadEntries failed: \(error.localizedDescription)")
                        #endif
                        return nil
                    }
                }
            }
            for await r in group {
                if let r { results.append(r) }
            }
        }

        // Parse results into lookup dict keyed by displayName
        var todayBest: [GameType: [String: (score: Int, rank: Int)]] = [:]
        for r in results {
            todayBest[r.game] = Dictionary(
                uniqueKeysWithValues: r.entries.map { ($0.displayName, ($0.score, $0.rank)) }
            )
        }

        // Build per-friend summaries — match by displayName
        var newSummaries: [String: FriendTodaySummary] = [:]
        for friend in friends {
            let name = friend.displayName
            var perGame: [GameType: FriendTodayEntry] = [:]
            for game in GameType.allCases {
                let entry = todayBest[game]?[name]
                perGame[game] = FriendTodayEntry(score: entry?.score, rank: entry?.rank)
            }
            let summary = FriendTodaySummary(player: friend, perGame: perGame)
            // Key by gamePlayerID for internal lookups (FriendRow etc.)
            newSummaries[friend.gamePlayerID] = summary
        }

        #if DEBUG
        let totalScores = newSummaries.values.reduce(0) { $0 + $1.gamesSolvedToday }
        print("[FriendsService] Summaries built for \(newSummaries.count) friends, \(totalScores) total scores found")
        #endif

        summaries = newSummaries
        summaryCachedAt = Date()
    }

    // MARK: - Friend Profile (all-time stats)

    /// Loads full all-time stats for a specific friend across all 5 games.
    /// Used by FriendProfileView — one call when the profile sheet opens.
    func loadFriendProfile(for friend: GKPlayer) async throws -> [GameType: FriendGameStats] {
        struct RawEntry: @unchecked Sendable {
            let game: GameType
            let score: Int?
            let rank: Int?
        }

        var rawEntries: [RawEntry] = []

        // BATCH-load all 5 leaderboards in one call (see loadTodaySummaries
        // for the rationale — concurrent per-id calls trigger GameKit
        // rate-limiting and return empty arrays).
        let allIDs = GameType.allCases.map { bestLeaderboardID($0) }
        let allBoards: [GKLeaderboard]
        do {
            allBoards = try await GKLeaderboard.loadLeaderboards(IDs: allIDs)
        } catch {
            #if DEBUG
            print("[FriendsService] loadFriendProfile batch loadLeaderboards failed: \(error.localizedDescription)")
            #endif
            // Return empty stats for all games rather than throwing — caller
            // renders the "no games yet" placeholder per game.
            return Dictionary(uniqueKeysWithValues: GameType.allCases.map {
                ($0, FriendGameStats(game: $0, bestAllTimeScore: nil, bestAllTimeRank: nil))
            })
        }
        let boardByID = Dictionary(
            uniqueKeysWithValues: allBoards.map { ($0.baseLeaderboardID, $0) }
        )

        // Now query each board's entries for the friend in parallel — these
        // are independent calls per loaded board, which GameKit handles fine.
        await withTaskGroup(of: RawEntry?.self) { group in
            for game in GameType.allCases {
                let leaderboardID = bestLeaderboardID(game)
                guard let board = boardByID[leaderboardID] else {
                    #if DEBUG
                    print("[FriendsService] loadFriendProfile: board missing for \(game.rawValue) (ID: \(leaderboardID))")
                    #endif
                    continue
                }
                group.addTask { [board] in
                    let e: GKLeaderboard.Entry?
                    do {
                        let result = try await board.loadEntries(for: [friend], timeScope: .allTime)
                        e = result.1.first  // .1 = entries array for the passed players
                    } catch {
                        #if DEBUG
                        print("[FriendsService] loadFriendProfile loadEntries(\(leaderboardID)) failed: \(error.localizedDescription)")
                        #endif
                        e = nil
                    }
                    return RawEntry(
                        game: game,
                        score: e.map { $0.score },
                        rank:  e.map { Int($0.rank) }
                    )
                }
            }
            for await r in group {
                if let r { rawEntries.append(r) }
            }
        }

        var bestByGame: [GameType: (score: Int, rank: Int)] = [:]
        for r in rawEntries {
            guard let score = r.score else { continue }
            bestByGame[r.game] = (score, r.rank ?? 0)
        }

        var stats: [GameType: FriendGameStats] = [:]
        for game in GameType.allCases {
            let best = bestByGame[game]
            stats[game] = FriendGameStats(
                game: game,
                bestAllTimeScore: best?.score,
                bestAllTimeRank:  best?.rank
            )
        }
        return stats
    }

    // MARK: - Local Player Stats

    /// Loads the local player's own all-time stats for head-to-head comparison.
    /// Reuses the same GK query path as loadFriendProfile — GKLocalPlayer.local
    /// is a GKPlayer subclass, so passing it directly works correctly.
    func loadLocalPlayerStats() async throws -> [GameType: FriendGameStats] {
        return try await loadFriendProfile(for: GKLocalPlayer.local)
    }

    // MARK: - Head-to-Head

    /// Compares local player vs a friend on one game's all-time best leaderboard.
    func headToHead(friend: GKPlayer, game: GameType) async throws -> HeadToHead {
        guard GKLocalPlayer.local.isAuthenticated else {
            throw GKError(.notAuthenticated)
        }

        let boardID = bestLeaderboardID(game)
        let boards  = try await GKLeaderboard.loadLeaderboards(IDs: [boardID])
        guard let board = boards.first else {
            throw GKError(.unknown)
        }

        // Load both players' entries simultaneously
        async let myEntries     = board.loadEntries(for: [GKLocalPlayer.local], timeScope: .allTime)
        async let theirEntries  = board.loadEntries(for: [friend], timeScope: .allTime)
        let (mine, theirs)      = try await (myEntries, theirEntries)

        let myBest     = mine.1.first   // .1 = entries for the passed players
        let theirBest  = theirs.1.first

        let myStats = FriendGameStats(
            game: game,
            bestAllTimeScore: myBest?.score,
            bestAllTimeRank:  myBest.map { Int($0.rank) }
        )
        let theirStats = FriendGameStats(
            game: game,
            bestAllTimeScore: theirBest?.score,
            bestAllTimeRank:  theirBest.map { Int($0.rank) }
        )
        return HeadToHead(game: game, myStats: myStats, theirStats: theirStats)
    }

    // MARK: - Leaderboard ID Helpers

    func bestLeaderboardID(_ game: GameType) -> String {
        switch game {
        case .signals: return GameCenterManager.Leaderboard.signalsDailyBest
        case .archive: return GameCenterManager.Leaderboard.archiveDailyBest
        case .cargo:   return GameCenterManager.Leaderboard.cargoDailyBest
        case .shift:   return GameCenterManager.Leaderboard.shiftDailyBest
        case .circuit: return GameCenterManager.Leaderboard.circuitDailyBest
        }
    }

    // MARK: - Private Helpers

    private func mapAuthStatus(_ status: GKFriendsAuthorizationStatus) -> FriendsAuthState {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized:    return .authorized
        case .denied:        return .denied
        case .restricted:    return .restricted
        @unknown default:    return .unknown
        }
    }
}
