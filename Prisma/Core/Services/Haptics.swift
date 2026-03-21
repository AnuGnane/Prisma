//
//  Haptics.swift
//  Prisma
//
//  Centralized haptic feedback generator for tactile game interactions.
//  Respects the user's haptics toggle in settings.
//

import UIKit

struct Haptics {
    private static var isEnabled: Bool { AppSettings.hapticsEnabled }
    private static var isLowPowerModeEnabled: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }
    private static var shouldPlay: Bool { isEnabled && !isLowPowerModeEnabled }

    /// For key presses and minor UI interactions.
    static func playLightImpact() {
        guard shouldPlay else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// For rigid actions like a physical tile flipping over.
    static func playRigidImpact() {
        guard shouldPlay else { return }
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// For moderate actions or game state changes.
    static func playMediumImpact() {
        guard shouldPlay else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// For successful game completion or validating a correct puzzle state.
    static func playSuccess() {
        guard shouldPlay else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// For invalid inputs (like a fake date) or game loss.
    static func playError() {
        guard shouldPlay else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}
