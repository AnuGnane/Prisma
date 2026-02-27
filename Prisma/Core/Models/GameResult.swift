//
//  GameResult.swift
//  Prisma
//

import Foundation
import SwiftData

@Model
final class GameResult {
    var gameTypeRaw: String
    var date: Date
    var score: Int
    var shareString: String
    var guessCount: Int
    var isDaily: Bool
    var durationSeconds: Double

    init(
        gameType: GameType,
        date: Date = .now,
        score: Int,
        shareString: String,
        guessCount: Int = 0,
        isDaily: Bool,
        durationSeconds: Double = 0
    ) {
        self.gameTypeRaw    = gameType.rawValue
        self.date           = date
        self.score          = score
        self.shareString    = shareString
        self.guessCount     = guessCount
        self.isDaily        = isDaily
        self.durationSeconds = durationSeconds
    }

    var gameType: GameType {
        GameType(rawValue: gameTypeRaw) ?? .signals
    }
}
