//
//  ShiftMove.swift
//  Prisma
//
//  Single slide operation for the 8×8 Shift grid.
//

import Foundation

enum ShiftMove: Equatable, Codable {
    case rowLeft(Int)
    case rowRight(Int)
    case columnUp(Int)
    case columnDown(Int)

    var description: String {
        switch self {
        case .rowLeft(let r):    return "Row \(r + 1) ←"
        case .rowRight(let r):   return "Row \(r + 1) →"
        case .columnUp(let c):   return "Col \(c + 1) ↑"
        case .columnDown(let c): return "Col \(c + 1) ↓"
        }
    }

    func apply(to grid: ShiftGrid) -> ShiftGrid {
        switch self {
        case .rowLeft(let r):    return grid.slideRowLeft(r)
        case .rowRight(let r):   return grid.slideRowRight(r)
        case .columnUp(let c):   return grid.slideColumnUp(c)
        case .columnDown(let c): return grid.slideColumnDown(c)
        }
    }

    var inverse: ShiftMove {
        switch self {
        case .rowLeft(let r):    return .rowRight(r)
        case .rowRight(let r):   return .rowLeft(r)
        case .columnUp(let c):   return .columnDown(c)
        case .columnDown(let c): return .columnUp(c)
        }
    }
}
