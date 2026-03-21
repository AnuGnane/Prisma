//
//  PrismaGameViewModel.swift
//  Prisma
//
//  Standardizes the interface for all puzzle games to easily support adding new games in the future.
//

import Foundation

@MainActor
protocol PrismaGameViewModel: AnyObject {
    var isDaily: Bool { get }
    var activeLevelId: Int? { get }
    var elapsedSeconds: Double { get }
    var timerString: String { get }
    var showingSolution: Bool { get }
    
    func reset()
    func giveUp()
    func showSolution()
    func hideSolution()
    func buildGameResult() -> GameResult
}
