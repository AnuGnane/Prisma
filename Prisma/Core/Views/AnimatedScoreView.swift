//
//  AnimatedScoreView.swift
//  Prisma
//
//  Counts up from 0 to a target score with a smooth animation on appear.
//

import SwiftUI

/// Displays a numeric score that counts up from 0 to `target` over `duration` seconds.
struct AnimatedScoreView: View {
    let target: Int
    var duration: Double = 1.2
    var font: Font = .system(size: 24, weight: .bold, design: .rounded)
    var color: Color = .primary

    @State private var displayed: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(displayed, format: .number)
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(displayed)))
            .onAppear {
                if reduceMotion {
                    displayed = target
                } else {
                    withAnimation(.easeOut(duration: duration)) {
                        displayed = target
                    }
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        AnimatedScoreView(target: 1000)
        AnimatedScoreView(target: 750, font: .title, color: .yellow)
    }
    .padding(40)
    .background(Color.black)
}
