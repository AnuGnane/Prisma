//
//  OnboardingView.swift
//  Prisma
//
//  Three-screen welcome carousel shown to first-time users.
//  Gated by a UserDefaults flag; never shown again after dismissal.
//

import SwiftUI

// MARK: - Onboarding Page Model

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("onboarding.hasSeenWelcome") private var hasSeenWelcome = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentPage = 0
    @State private var iconScale: CGFloat = 0.7
    @State private var iconOpacity: Double = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "sparkles",
            iconColor: AppTheme.signals,
            title: "Welcome to Prisma",
            body: "Four beautifully crafted daily puzzles.\nOne app. A new challenge every day."
        ),
        OnboardingPage(
            icon: "flame.fill",
            iconColor: .orange,
            title: "Build Your Streak",
            body: "Play every day to grow your streak.\nA small habit that brings a big reward."
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            iconColor: AppTheme.shift,
            title: "You're All Set",
            body: "Signals, Archive, Cargo, Shift.\nPick a game and start playing."
        )
    ]

    var body: some View {
        ZStack {
            AppTheme.appBackground()

            VStack(spacing: 0) {
                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 360)
                .onChange(of: currentPage) {
                    animateIconEntrance()
                }

                // Page dots
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(width: index == currentPage ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: currentPage)
                    }
                }
                .padding(.top, 32)

                Spacer()

                // CTA Buttons
                VStack(spacing: 12) {
                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation(.spring(response: 0.4)) {
                                currentPage += 1
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: AppTheme.brandGradient,
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                        )

                        Button("Skip") { dismiss() }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary.opacity(0.4))
                    } else {
                        Button("Start Playing") { dismiss() }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: AppTheme.brandGradient,
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                            )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .onAppear { animateIconEntrance() }
    }

    // MARK: - Page View

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(page.iconColor)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
            }
            .frame(height: 130)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Helpers

    private func animateIconEntrance() {
        iconScale = 0.7
        iconOpacity = 0
        if reduceMotion {
            iconScale = 1.0
            iconOpacity = 1.0
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
        }
    }

    private func dismiss() {
        if reduceMotion {
            hasSeenWelcome = true
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                hasSeenWelcome = true
            }
        }
    }
}

#Preview {
    OnboardingView()
}
