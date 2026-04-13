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
    @AppStorage("settings.notificationsEnabled") static var notificationsEnabled: Bool = false
    /// Hour of day (0–23) for the daily reminder. Default 18 = 6 PM.
    @AppStorage("settings.notificationHour") static var notificationHour: Int = 18
}
