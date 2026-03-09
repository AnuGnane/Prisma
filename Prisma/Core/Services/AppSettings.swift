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
    @AppStorage("settings.darkMode") static var prefersDarkMode: Bool = true
}
