//
//  SignalsLevel.swift
//  Prisma
//
//  Codable configuration for each Signals progression level.
//  Loaded from Resources/LevelData/signals_levels.json.
//

import Foundation

struct SignalsLevel: Codable, Identifiable {
    let id: Int
    let maxGuesses: Int
    let codeLength: Int
    let digitMin: Int
    let digitMax: Int

    var digitRange: ClosedRange<Int> { digitMin...digitMax }
}
