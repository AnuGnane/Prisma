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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cargo:   return "Cargo"
        case .shift:   return "Shift"
        case .signals: return "Signals"
        case .archive: return "Archive"
        }
    }

    var description: String {
        switch self {
        case .cargo:   return "Pack the pieces into the hold"
        case .shift:   return "Slide the grid to spell the words"
        case .signals: return "Break the 4-digit code"
        case .archive: return "Guess the historic date"
        }
    }

    var iconName: String {
        switch self {
        case .signals: return "antenna.radiowaves.left.and.right"
        case .archive: return "clock.arrow.circlepath"
        case .cargo:   return "shippingbox.fill"
        case .shift:   return "slider.horizontal.3"
        }
    }
}
