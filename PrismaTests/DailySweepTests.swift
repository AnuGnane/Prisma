//
//  DailySweepTests.swift
//  PrismaTests
//
//  Tests for the Daily Sweep detection logic and GameResult.formattedMetric helper.
//

import Foundation
import Testing
@testable import Prisma

// MARK: - Sweep Detection

struct DailySweepDetectionTests {

    // MARK: - Happy path

    @Test func allFiveWinsIsASweep() {
        let results = GameType.allCases.map { game in
            GameResult(gameType: game, score: 900, shareString: "", guessCount: 2, isDaily: true)
        }
        #expect(DailySweepView.isSweep(results))
    }

    // MARK: - Negative cases

    @Test func fourWinsIsNotASweep() {
        let results = [GameType.signals, .archive, .cargo, .shift].map { game in
            GameResult(gameType: game, score: 900, shareString: "", isDaily: true)
        }
        #expect(!DailySweepView.isSweep(results))
    }

    @Test func fiveGamesButOneLostIsNotASweep() {
        var results = GameType.allCases.map { game in
            GameResult(gameType: game, score: 900, shareString: "", isDaily: true)
        }
        // Replace Circuit with a loss (score == 0)
        results = results.map { r in
            if r.gameType == .circuit {
                return GameResult(gameType: .circuit, score: 0, shareString: "", isDaily: true)
            }
            return r
        }
        #expect(!DailySweepView.isSweep(results))
    }

    @Test func emptyResultsIsNotASweep() {
        #expect(!DailySweepView.isSweep([]))
    }

    @Test func duplicateGameTypesDoNotInflateCount() {
        // Four distinct game types, but Signals appears twice — still only 4 distinct wins
        let results = [
            GameResult(gameType: .signals, score: 900, shareString: "", isDaily: true),
            GameResult(gameType: .signals, score: 700, shareString: "", isDaily: true),
            GameResult(gameType: .archive, score: 900, shareString: "", isDaily: true),
            GameResult(gameType: .cargo,   score: 900, shareString: "", isDaily: true),
            GameResult(gameType: .shift,   score: 900, shareString: "", isDaily: true),
        ]
        #expect(!DailySweepView.isSweep(results))
    }

    @Test func allFiveWinsWithDuplicatesIsStillASweep() {
        // One extra Signals result on top of a full sweep — still counts
        var results = GameType.allCases.map { game in
            GameResult(gameType: game, score: 900, shareString: "", isDaily: true)
        }
        results.append(GameResult(gameType: .signals, score: 800, shareString: "", isDaily: true))
        #expect(DailySweepView.isSweep(results))
    }
}

// MARK: - GameResult.formattedMetric

struct FormattedMetricTests {

    @Test func signalsTwoGuessesFormatted() {
        let r = GameResult(gameType: .signals, score: 800, shareString: "", guessCount: 2, isDaily: true)
        #expect(r.formattedMetric == "2 guesses")
    }

    @Test func signalsOneGuessFormatted() {
        let r = GameResult(gameType: .signals, score: 900, shareString: "", guessCount: 1, isDaily: true)
        #expect(r.formattedMetric == "1 guess")
    }

    @Test func archiveThreeGuessesFormatted() {
        let r = GameResult(gameType: .archive, score: 700, shareString: "", guessCount: 3, isDaily: true)
        #expect(r.formattedMetric == "3 guesses")
    }

    @Test func cargoUnderSixtySecondsFormatted() {
        let r = GameResult(gameType: .cargo, score: 870, shareString: "", guessCount: 0, isDaily: true, durationSeconds: 42)
        #expect(r.formattedMetric == "42s")
    }

    @Test func cargoOverSixtySecondsFormatted() {
        let r = GameResult(gameType: .cargo, score: 870, shareString: "", guessCount: 0, isDaily: true, durationSeconds: 125)
        #expect(r.formattedMetric == "2:05")
    }

    @Test func circuitExactlyOneMinuteFormatted() {
        let r = GameResult(gameType: .circuit, score: 900, shareString: "", guessCount: 10, isDaily: true, durationSeconds: 60)
        #expect(r.formattedMetric == "1:00")
    }

    @Test func shiftTenMovesFormatted() {
        let r = GameResult(gameType: .shift, score: 750, shareString: "", guessCount: 10, isDaily: true)
        #expect(r.formattedMetric == "10 moves")
    }

    @Test func shiftOneMoveFormatted() {
        let r = GameResult(gameType: .shift, score: 950, shareString: "", guessCount: 1, isDaily: true)
        #expect(r.formattedMetric == "1 move")
    }
}
