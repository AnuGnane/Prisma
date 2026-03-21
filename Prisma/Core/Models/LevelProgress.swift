//
//  LevelProgress.swift
//  Prisma
//
//  Tracks offline progression for the Local levels mode.
//  Each level gets one attempt — win or lose, it's marked as played.
//

import Foundation
import SwiftData

@Model
final class LevelProgress {
    var gameTypeRaw: String = ""
    var levelId: Int = 0
    var isPlayed: Bool = false          // Has the player attempted this level?
    var won: Bool = false               // Did they win?
    var score: Int = 0              // 0 if lost
    var guessesUsed: Int = 0        // Number of guesses taken
    var playedDate: Date? = nil
    var durationSeconds: Double = 0.0 // Solve time in seconds

    init(
        gameTypeRaw: String,
        levelId: Int,
        isPlayed: Bool = false,
        won: Bool = false,
        score: Int = 0,
        guessesUsed: Int = 0,
        playedDate: Date? = nil,
        durationSeconds: Double = 0
    ) {
        self.gameTypeRaw = gameTypeRaw
        self.levelId = levelId
        self.isPlayed = isPlayed
        self.won = won
        self.score = score
        self.guessesUsed = guessesUsed
        self.playedDate = playedDate
        self.durationSeconds = durationSeconds
    }
}
