//
//  GameType.swift
//  Prisma
//

import Foundation

enum GameType: String, Codable, CaseIterable, Identifiable {
    case cargo
    case shift
    case signals
    case archive
    case circuit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cargo:   return "Cargo"
        case .shift:   return "Shift"
        case .signals: return "Signals"
        case .archive: return "Archive"
        case .circuit: return "Circuit"
        }
    }

    var description: String {
        switch self {
        case .cargo:   return "Pack the pieces into the hold"
        case .shift:   return "Slide the grid to spell the words"
        case .signals: return "Break the 4-digit code"
        case .archive: return "Guess the historic date"
        case .circuit: return "Route the signal to its target"
        }
    }

    var iconName: String {
        switch self {
        case .signals: return "antenna.radiowaves.left.and.right"
        case .archive: return "clock.arrow.circlepath"
        case .cargo:   return "shippingbox.fill"
        case .shift:   return "slider.horizontal.3"
        case .circuit: return "point.3.connected.trianglepath.dotted"
        }
    }

    /// Emoji shorthand for share strings.
    var emoji: String {
        switch self {
        case .signals: return "📡"
        case .archive: return "📅"
        case .cargo:   return "📦"
        case .shift:   return "🔀"
        case .circuit: return "⚡️"
        }
    }

    /// Number of curated local progression levels available for this game.
    ///
    /// Used by `LevelSelectorView` to size the tile grid and by progress stats
    /// to compute completion percentages. As each game's catalog is expanded
    /// toward the 150-level floor, bump its value here. Keeping this per-game
    /// means a Signals bump doesn't expose unloadable tiles for other games.
    var localLevelCount: Int {
        switch self {
        case .signals: return 150
        case .archive: return 100
        case .cargo:   return 150
        case .shift:   return 150
        case .circuit: return 150
        }
    }
}
