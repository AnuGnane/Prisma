//
//  ConfettiView.swift
//  Prisma
//
//  Reusable confetti burst animation overlay.
//  Shows coloured particles that rise, drift, and fade out.
//

import SwiftUI

struct ConfettiView: View {
    let isActive: Bool
    var particleCount: Int = 40

    @State private var particles: [ConfettiParticle] = []
    @State private var animationPhase = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .offset(
                            x: animationPhase ? p.endX : p.startX,
                            y: animationPhase ? p.endY : p.startY
                        )
                        .opacity(animationPhase ? 0 : 1)
                        .scaleEffect(animationPhase ? 0.3 : 1)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onChange(of: isActive) { _, active in
                if active {
                    spawnParticles(in: geo.size)
                    withAnimation(.easeOut(duration: 1.8)) {
                        animationPhase = true
                    }
                    // Reset after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        animationPhase = false
                        particles = []
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func spawnParticles(in size: CGSize) {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple, .pink,
            Color(red: 0.24, green: 0.65, blue: 0.36),
            Color(red: 0.65, green: 0.24, blue: 0.85),
            Color(red: 0.24, green: 0.52, blue: 0.85)
        ]

        particles = (0..<particleCount).map { i in
            ConfettiParticle(
                id: i,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...10),
                startX: size.width / 2 + CGFloat.random(in: -20...20),
                startY: size.height * 0.4,
                endX: CGFloat.random(in: -size.width * 0.5 ... size.width * 0.5),
                endY: CGFloat.random(in: -size.height * 0.6 ... -size.height * 0.1)
            )
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id: Int
    let color: Color
    let size: CGFloat
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
}
