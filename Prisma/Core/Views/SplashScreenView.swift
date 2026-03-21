//
//  SplashScreenView.swift
//  Prisma
//
//  Animated launch screen shown briefly before the main app.
//  Features the "Prisma" logo with gradient text, a scale+fade entrance,
//  and a tagline that fades in with a slight delay.
//

import SwiftUI

struct SplashScreenView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background
            AppTheme.appBackground()

            // Subtle glow behind logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.shift.opacity(0.15),
                            AppTheme.cascadeBlue.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .opacity(glowOpacity)
                .blur(radius: 30)

            VStack(spacing: 16) {
                // App icon
                Image(systemName: "sparkle")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.shift, AppTheme.cascadeBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(logoOpacity)

                // Logo text
                Text("Prisma")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.shift, AppTheme.cascadeBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                // Tagline
                Text("Your daily cognitive signal.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.5))
                    .opacity(taglineOpacity)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else {
                logoScale = 1.0
                logoOpacity = 1.0
                taglineOpacity = 1.0
                glowOpacity = 1.0
                return
            }

            // Logo entrance
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }

            // Glow pulse
            withAnimation(.easeInOut(duration: 0.8).delay(0.1)) {
                glowOpacity = 1.0
            }

            // Tagline fade-in
            withAnimation(.easeIn(duration: 0.5).delay(0.4)) {
                taglineOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
