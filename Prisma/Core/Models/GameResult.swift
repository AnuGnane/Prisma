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

    // MARK: - Display helpers

    /// Formats raw elapsed seconds into "42s" or "1:45".
    static func formatElapsedSeconds(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return "\(m):\(s.formatted(.number.precision(.integerLength(2))))"
        } else {
            return "\(seconds)s"
        }
    }

    /// Human-readable metric for this result:
    ///  - Signals / Archive → "X guess(es)"
    ///  - Shift             → "X move(s)"
    ///  - Cargo / Circuit   → elapsed time ("42s" / "1:45")
    var formattedMetric: String {
        switch gameType {
        case .signals, .archive:
            return "\(guessCount) \(guessCount == 1 ? "guess" : "guesses")"
        case .shift:
            return "\(guessCount) \(guessCount == 1 ? "move" : "moves")"
        case .cargo, .circuit:
            return GameResult.formatElapsedSeconds(Int(durationSeconds))
        }
    }
}
