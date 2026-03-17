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
    var particleCount: Int = 50
    var accentColor: Color? = nil

    @State private var particles: [ConfettiParticle] = []
    @State private var animationPhase = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Group {
                        switch p.shape {
                        case 0:  Circle().fill(p.color)
                        case 1:  RoundedRectangle(cornerRadius: 2).fill(p.color)
                        default: Capsule().fill(p.color)
                        }
                    }
                    .frame(width: p.size, height: p.size * p.aspectRatio)
                    .rotationEffect(.degrees(animationPhase ? p.rotation : 0))
                    .offset(
                        x: animationPhase ? p.endX : p.startX,
                        y: animationPhase ? p.endY : p.startY
                    )
                    .opacity(animationPhase ? 0 : 1)
                    .scaleEffect(animationPhase ? 0.2 : 1)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onChange(of: isActive) { _, active in
                if active {
                    spawnParticles(in: geo.size)
                    withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                        animationPhase = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        animationPhase = false
                        particles = []
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func spawnParticles(in size: CGSize) {
        var colors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple, .pink,
            AppTheme.signals, AppTheme.shift, AppTheme.archive
        ]
        if let accent = accentColor {
            colors.append(contentsOf: [accent, accent, accent])
        }

        particles = (0..<particleCount).map { i in
            ConfettiParticle(
                id: i,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...10),
                aspectRatio: CGFloat.random(in: 0.5...1.5),
                shape: Int.random(in: 0...2),
                rotation: Double.random(in: -360...360),
                startX: size.width / 2 + CGFloat.random(in: -30...30),
                startY: size.height * 0.4,
                endX: CGFloat.random(in: -size.width * 0.5 ... size.width * 0.5),
                endY: CGFloat.random(in: -size.height * 0.6 ... -size.height * 0.05)
            )
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id: Int
    let color: Color
    let size: CGFloat
    let aspectRatio: CGFloat
    let shape: Int
    let rotation: Double
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
}
