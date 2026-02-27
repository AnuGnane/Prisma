//
//  ShareStringGenerator.swift
//  Prisma
//
//  Protocol that every game's ViewModel must conform to.
//  Produces a Wordle-style emoji string for sharing on completion.
//

import Foundation

protocol ShareStringGenerator {
    /// Generates the emoji share string for the completed game.
    /// Example: "Signals 🟩🟨⬜⬜ ⬆️\n🟩🟩🟩🟩 ✅"
    func generateShareString() -> String
}
