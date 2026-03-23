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

    /// Play a completion/success sound (soft, at reduced volume).
    static func playSuccess() {
        guard shouldPlay else { return }
        // 1110 = short key-press chime — considerably quieter than 1025 (new mail)
        AudioServicesPlaySystemSound(1110)
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
