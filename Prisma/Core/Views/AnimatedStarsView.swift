//
//  AnimatedStarsView.swift
//  Prisma
//
//  A reusable star-rating row that pops each star in sequentially
//  with a spring scale animation and a golden glow sparkle on reveal.
//

import SwiftUI

/// Displays 1–3 stars that animate in one-by-one with a spring pop + sparkle.
struct AnimatedStarsView: View {
    let title: String
    var count: Int = 3
    /// Tints the title label to match the completing game's brand colour.
    var accentColor: Color = AppTheme.cascadeBlue

    @State private var visibleStars: [Bool] = [false, false, false]
    @State private var glowStars: [Bool]    = [false, false, false]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let totalStars = 3
    private let starDelay  = 0.18  // seconds between each star

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(0..<totalStars, id: \.self) { index in
                    let isFilled = index < count
                    Image(systemName: isFilled ? "star.fill" : "star")
                        .font(.system(size: 32))
                        .foregroundStyle(isFilled ? .yellow : Color.primary.opacity(0.25))
                        // Glow layer
                        .shadow(
                            color: isFilled && glowStars[index] ? .yellow.opacity(0.85) : .clear,
                            radius: glowStars[index] ? 12 : 0
                        )
                        // Pop-in scale
                        .scaleEffect(visibleStars[index] ? 1.0 : (reduceMotion ? 1.0 : 0.01))
                        .opacity(visibleStars[index] ? 1.0 : (reduceMotion ? 1.0 : 0.0))
                }
            }

            Text(title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(accentColor)
                .opacity(visibleStars[min(count - 1, 2)] ? 1.0 : (reduceMotion ? 1.0 : 0.0))
                .animation(reduceMotion ? nil : .easeIn(duration: 0.2), value: visibleStars[min(count - 1, 2)])
        }
        .onAppear {
            animateStars()
        }
    }

    private func animateStars() {
        guard !reduceMotion else {
            visibleStars = [true, true, true]
            glowStars    = (0..<totalStars).map { $0 < count }
            return
        }

        for i in 0..<count {
            let delay = Double(i) * starDelay
            // Pop in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55).delay(delay)) {
                visibleStars[i] = true
            }
            // Glow on
            withAnimation(.easeOut(duration: 0.25).delay(delay + 0.15)) {
                glowStars[i] = true
            }
            // Glow fade
            withAnimation(.easeOut(duration: 0.5).delay(delay + 0.55)) {
                glowStars[i] = false
            }
        }
    }
}

#Preview("Animated Stars") {
    VStack(spacing: 32) {
        AnimatedStarsView(title: "PUZZLE COMPLETE", count: 3)
        AnimatedStarsView(title: "WELL DONE", count: 2)
        AnimatedStarsView(title: "KEEP GOING", count: 1)
    }
    .padding(40)
    .background(Color.black)
}
