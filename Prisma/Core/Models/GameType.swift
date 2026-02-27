//
//  GameType.swift
//  Prisma
//

import Foundation

enum GameType: String, Codable, CaseIterable, Identifiable {
    case cargo
    case shift
    case orbit
    case signals

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cargo:   return "Cargo"
        case .shift:   return "Shift"
        case .orbit:   return "Orbit"
        case .signals: return "Signals"
        }
    }

    var description: String {
        switch self {
        case .cargo:   return "Pack the pieces into the hold"
        case .shift:   return "Slide the grid to spell the words"
        case .orbit:   return "Tap when the marker hits the target"
        case .signals: return "Break the 4-digit code"
        }
    }
}
