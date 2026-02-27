//
//  Haptics.swift
//  Prisma
//
//  Centralized haptic feedback generator for tactile game interactions.
//

import UIKit

struct Haptics {
    /// For key presses and minor UI interactions.
    static func playLightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// For rigid actions like a physical tile flipping over.
    static func playRigidImpact() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// For moderate actions or game state changes.
    static func playMediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// For successful game completion or validating a correct puzzle state.
    static func playSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// For invalid inputs (like a fake date) or game loss.
    static func playError() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}
