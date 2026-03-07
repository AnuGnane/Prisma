//
//  SignalsGuessWithFeedback.swift
//  Prisma
//
//  Runtime model pairing a Signals guess with its feedback.
//  Used for displaying guess history in the game and history views.
//

import Foundation

/// Pairs a Signals guess with its corresponding feedback
struct SignalsGuessWithFeedback: Equatable {
    let guess: SignalsGuess
    let feedback: SignalsFeedback
}
