//
//  ArchiveGuessWithFeedback.swift
//  Prisma
//
//  Runtime model pairing an Archive guess with its feedback.
//  Used for displaying guess history in the game and history views.
//

import Foundation

/// Pairs an Archive guess with its corresponding feedback
struct ArchiveGuessWithFeedback: Equatable {
    let guess: ArchiveGuess
    let feedback: ArchiveFeedback
}
