//
//  SoundManager.swift
//  Prisma
//
//  Lightweight sound effects manager using system sounds.
//  Respects the user's sound toggle in settings.
//

import UIKit
import AudioToolbox

struct SoundManager {
    private static var isEnabled: Bool { AppSettings.soundEnabled }
    private static var isLowPowerModeEnabled: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }
    private static var shouldPlay: Bool { isEnabled && !isLowPowerModeEnabled }

    /// Play a light tap sound (e.g., key press).
    static func playTap() {
        guard shouldPlay else { return }
        AudioServicesPlaySystemSound(1104)
    }

    /// Play a completion/success sound.
    static func playSuccess() {
        guard shouldPlay else { return }
        AudioServicesPlaySystemSound(1025)
    }

    /// Play a subtle click (e.g., piece snap).
    static func playClick() {
        guard shouldPlay else { return }
        AudioServicesPlaySystemSound(1105)
    }

    /// Play an error/invalid sound.
    static func playError() {
        guard shouldPlay else { return }
        AudioServicesPlaySystemSound(1073)
    }
}
