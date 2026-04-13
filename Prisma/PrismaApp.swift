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
    @AppStorage("onboarding.hasSeenWelcome") private var hasSeenWelcome = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = true

    init() {
        // Authenticate with Game Center on launch.
        // Calls are guarded with `guard isAuthenticated` — safe to call even without a paid account.
        GameCenterManager.shared.authenticate()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
            .sheet(isPresented: .constant(!hasSeenWelcome && !showSplash)) {
                OnboardingView()
                    .interactiveDismissDisabled()
            }
            .task {
                try? await Task.sleep(for: .seconds(1.8))
                if reduceMotion {
                    showSplash = false
                } else {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
        .modelContainer(PersistenceManager.container)
    }
}
