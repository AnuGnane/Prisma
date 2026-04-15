//
//  GameResult.swift
//  Prisma
//

import Foundation
import SwiftData

@Model
final class GameResult {
    var gameTypeRaw: String = ""
    var date: Date = Date.now
    var score: Int = 0
    var shareString: String = ""
    var guessCount: Int = 0
    var isDaily: Bool = false
    var durationSeconds: Double = 0.0
    var levelId: Int? = nil  // For local games only, nil for daily games
    
    // Game state persistence properties
    var cargoStateJSON: String?
    var signalsStateJSON: String?
    var archiveStateJSON: String?
    var shiftStateJSON: String?
    var circuitStateJSON: String?

    init(
        gameType: GameType,
        date: Date = .now,
        score: Int,
        shareString: String,
        guessCount: Int = 0,
        isDaily: Bool,
        durationSeconds: Double = 0,
        levelId: Int? = nil,
        cargoStateJSON: String? = nil,
        signalsStateJSON: String? = nil,
        archiveStateJSON: String? = nil,
        shiftStateJSON: String? = nil,
        circuitStateJSON: String? = nil
    ) {
        self.gameTypeRaw    = gameType.rawValue
        self.date           = date
        self.score          = score
        self.shareString    = shareString
        self.guessCount     = guessCount
        self.isDaily        = isDaily
        self.durationSeconds = durationSeconds
        self.levelId        = levelId
        self.cargoStateJSON = cargoStateJSON
        self.signalsStateJSON = signalsStateJSON
        self.archiveStateJSON = archiveStateJSON
        self.shiftStateJSON = shiftStateJSON
        self.circuitStateJSON = circuitStateJSON
    }

    var gameType: GameType {
        GameType(rawValue: gameTypeRaw) ?? .signals
    }
}
