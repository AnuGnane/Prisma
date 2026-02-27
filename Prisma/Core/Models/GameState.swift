//
//  GameState.swift
//  Prisma
//

import Foundation

enum GameState: Equatable {
    case notStarted
    case inProgress
    case completed(score: Int)
    case failed

    var isOver: Bool {
        switch self {
        case .completed, .failed: return true
        default: return false
        }
    }

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var score: Int? {
        if case .completed(let s) = self { return s }
        return nil
    }
}
