import Testing
import Foundation
@testable import Prisma

private struct ScoreSubmission: Equatable {
    let score: Int
    let leaderboardIDs: [String]
}

private struct AchievementSubmission: Equatable {
    let id: String
    let percentComplete: Double
}

private struct LeaderboardEntry: Equatable {
    let playerName: String
    let score: Int
}

private protocol GameCenterService {
    func submitScore(_ score: Int, leaderboardIDs: [String]) async throws
    func reportAchievement(_ id: String, percentComplete: Double) async throws
}

private protocol LeaderboardService {
    func fetchTopEntries(limit: Int) async throws -> [LeaderboardEntry]
}

private actor MockGameCenterService: GameCenterService {
    private(set) var submittedScores: [ScoreSubmission] = []
    private(set) var submittedAchievements: [AchievementSubmission] = []

    var shouldFailScoreSubmission = false
    var shouldFailAchievementSubmission = false

    enum MockError: Error {
        case scoreSubmissionFailed
        case achievementSubmissionFailed
    }

    func submitScore(_ score: Int, leaderboardIDs: [String]) async throws {
        if shouldFailScoreSubmission {
            throw MockError.scoreSubmissionFailed
        }
        submittedScores.append(ScoreSubmission(score: score, leaderboardIDs: leaderboardIDs))
    }

    func reportAchievement(_ id: String, percentComplete: Double) async throws {
        if shouldFailAchievementSubmission {
            throw MockError.achievementSubmissionFailed
        }
        submittedAchievements.append(AchievementSubmission(id: id, percentComplete: percentComplete))
    }

    func setShouldFailScoreSubmission(_ value: Bool) {
        shouldFailScoreSubmission = value
    }

    func setShouldFailAchievementSubmission(_ value: Bool) {
        shouldFailAchievementSubmission = value
    }

    func snapshotScores() -> [ScoreSubmission] {
        submittedScores
    }

    func snapshotAchievements() -> [AchievementSubmission] {
        submittedAchievements
    }
}

private actor MockLeaderboardService: LeaderboardService {
    private let entries: [LeaderboardEntry]
    var shouldFail = false

    enum MockError: Error {
        case fetchFailed
    }

    init(entries: [LeaderboardEntry]) {
        self.entries = entries
    }

    func fetchTopEntries(limit: Int) async throws -> [LeaderboardEntry] {
        if shouldFail {
            throw MockError.fetchFailed
        }

        let sorted = entries.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.playerName < rhs.playerName
            }
            return lhs.score > rhs.score
        }
        return Array(sorted.prefix(max(0, limit)))
    }

    func setShouldFail(_ value: Bool) {
        shouldFail = value
    }
}

private struct AsyncGameCenterCoordinator {
    let service: GameCenterService

    func submitDailyWin(score: Int) async throws {
        try await service.submitScore(
            score,
            leaderboardIDs: [
                GameCenterManager.Leaderboard.signalsDailyBest,
                GameCenterManager.Leaderboard.signalsDailyStreak
            ]
        )
    }

    func submitProgressAchievement(current: Int, target: Int, achievementID: String) async throws {
        let ratio = target > 0 ? (Double(current) / Double(target)) : 0
        let percent = min(100.0, max(0, ratio * 100))
        try await service.reportAchievement(achievementID, percentComplete: percent)
    }
}

private struct AsyncLeaderboardCoordinator {
    let service: LeaderboardService

    func topThree() async throws -> [LeaderboardEntry] {
        try await service.fetchTopEntries(limit: 3)
    }
}

struct AsyncServiceTests {

    @Test("Mocked Game Center async score submission records expected leaderboard payload")
    func asyncGameCenterScoreSubmission() async throws {
        let mock = MockGameCenterService()
        let coordinator = AsyncGameCenterCoordinator(service: mock)

        try await coordinator.submitDailyWin(score: 420)

        let submissions = await mock.snapshotScores()
        #expect(submissions.count == 1)
        #expect(submissions.first == ScoreSubmission(
            score: 420,
            leaderboardIDs: [
                GameCenterManager.Leaderboard.signalsDailyBest,
                GameCenterManager.Leaderboard.signalsDailyStreak
            ]
        ))
    }

    @Test("Mocked Game Center async submission failures propagate for caller handling")
    func asyncGameCenterFailurePropagation() async {
        let mock = MockGameCenterService()
        let coordinator = AsyncGameCenterCoordinator(service: mock)
        await mock.setShouldFailScoreSubmission(true)

        await #expect(throws: MockGameCenterService.MockError.scoreSubmissionFailed) {
            try await coordinator.submitDailyWin(score: 250)
        }
    }

    @Test("Mocked progress achievements clamp percent complete to [0, 100]")
    func asyncGameCenterAchievementProgressClamping() async throws {
        let mock = MockGameCenterService()
        let coordinator = AsyncGameCenterCoordinator(service: mock)

        try await coordinator.submitProgressAchievement(
            current: 130,
            target: 100,
            achievementID: GameCenterManager.Achievement.local100
        )

        let achievements = await mock.snapshotAchievements()
        #expect(achievements.count == 1)
        #expect(achievements.first == AchievementSubmission(
            id: GameCenterManager.Achievement.local100,
            percentComplete: 100
        ))
    }

    @Test("Leaderboard async placeholder returns top scores in deterministic order")
    func asyncLeaderboardOrdering() async throws {
        let mock = MockLeaderboardService(entries: [
            LeaderboardEntry(playerName: "Nina", score: 810),
            LeaderboardEntry(playerName: "Alex", score: 810),
            LeaderboardEntry(playerName: "Kai", score: 900),
            LeaderboardEntry(playerName: "Sam", score: 770)
        ])
        let coordinator = AsyncLeaderboardCoordinator(service: mock)

        let top = try await coordinator.topThree()

        #expect(top.count == 3)
        #expect(top[0] == LeaderboardEntry(playerName: "Kai", score: 900))
        #expect(top[1] == LeaderboardEntry(playerName: "Alex", score: 810))
        #expect(top[2] == LeaderboardEntry(playerName: "Nina", score: 810))
    }

    @Test("Leaderboard async placeholder propagates fetch errors cleanly")
    func asyncLeaderboardFailurePropagation() async {
        let mock = MockLeaderboardService(entries: [])
        let coordinator = AsyncLeaderboardCoordinator(service: mock)
        await mock.setShouldFail(true)

        await #expect(throws: MockLeaderboardService.MockError.fetchFailed) {
            _ = try await coordinator.topThree()
        }
    }
}
