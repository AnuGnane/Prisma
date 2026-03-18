//
//  AppSettings.swift
//  Prisma
//
//  Centralized @AppStorage wrapper for user preferences.
//

import SwiftUI

struct AppSettings {
    @AppStorage("settings.hapticsEnabled") static var hapticsEnabled: Bool = true
    @AppStorage("settings.soundEnabled") static var soundEnabled: Bool = true
    @AppStorage("settings.appearanceMode") static var appearanceMode: String = AppearanceMode.dark.rawValue
    @AppStorage("settings.showGameTimer") static var showGameTimer: Bool = true
}
