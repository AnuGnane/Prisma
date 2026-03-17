//
//  PrismaApp.swift
//  Prisma
//
//  Created by Anu Gnana on 27/02/2026.
//

import SwiftUI
import SwiftData

@main
struct PrismaApp: App {
    @AppStorage("settings.appearanceMode") private var appearanceMode = AppearanceMode.dark.rawValue

    init() {
        // GameCenterManager.shared.authenticate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
        }
        .modelContainer(PersistenceManager.container)
    }
}
