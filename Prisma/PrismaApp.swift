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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(PersistenceManager.container)
    }
}
