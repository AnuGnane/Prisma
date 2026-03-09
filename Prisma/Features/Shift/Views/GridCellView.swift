//
//  GridCellView.swift
//  Prisma
//
//  Premium glassmorphism cell for the 8×8 Shift grid.
//

import SwiftUI

struct GridCellView: View {
    let letter: Character
    let isHighlighted: Bool
    let isHintCell: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(bgFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(borderColor, lineWidth: 1.2)
                )
                .shadow(color: shadowColor, radius: isHighlighted ? 6 : 1)

            Text(String(letter))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
        }
    }

    private var bgFill: some ShapeStyle {
        if isHintCell {
            return AnyShapeStyle(
                LinearGradient(colors: [.orange.opacity(0.35), .yellow.opacity(0.2)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        } else if isHighlighted {
            return AnyShapeStyle(
                LinearGradient(colors: [Color(red: 0.4, green: 0.2, blue: 0.85).opacity(0.5),
                                        Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.35)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        } else {
            return AnyShapeStyle(Color(white: 0.12))
        }
    }

    private var borderColor: Color {
        isHintCell ? .orange.opacity(0.7) :
        isHighlighted ? Color(red: 0.5, green: 0.3, blue: 0.95).opacity(0.6) :
            .white.opacity(0.08)
    }

    private var shadowColor: Color {
        isHintCell ? .orange.opacity(0.4) :
        isHighlighted ? Color(red: 0.4, green: 0.2, blue: 0.85).opacity(0.5) :
            .clear
    }

    private var textColor: Color {
        isHintCell ? .orange :
        isHighlighted ? .white :
            .white.opacity(0.85)
    }
}
