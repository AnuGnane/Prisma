//
//  ParIndicatorView.swift
//  Prisma
//
//  Created by Kiro on 2024.
//

import SwiftUI

/// Visual indicator showing player's move efficiency compared to optimal solution
/// Displays "Par N" text with a colored circle indicator based on performance level
struct ParIndicatorView: View {
    let currentMoves: Int
    let optimalMoves: Int
    
    /// Compute performance level based on current moves vs optimal
    var performance: Performance {
        if currentMoves <= optimalMoves {
            return .excellent
        } else if currentMoves <= optimalMoves + 3 {
            return .good
        } else if currentMoves <= optimalMoves + 6 {
            return .fair
        } else {
            return .poor
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Par \(optimalMoves)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            
            Circle()
                .fill(performance.color)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.12))
        )
    }
    
    /// Performance levels with associated colors
    enum Performance: Equatable {
        case excellent  // At or below par
        case good       // 1-3 moves over par
        case fair       // 4-6 moves over par
        case poor       // 7+ moves over par
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .yellow
            case .fair: return .orange
            case .poor: return .red
            }
        }
    }
}

// MARK: - Previews

#Preview("Excellent Performance") {
    ParIndicatorView(currentMoves: 5, optimalMoves: 5)
        .padding()
        .background(AppTheme.backgroundSecondary)
}

#Preview("Good Performance") {
    ParIndicatorView(currentMoves: 8, optimalMoves: 5)
        .padding()
        .background(AppTheme.backgroundSecondary)
}

#Preview("Fair Performance") {
    ParIndicatorView(currentMoves: 10, optimalMoves: 5)
        .padding()
        .background(AppTheme.backgroundSecondary)
}

#Preview("Poor Performance") {
    ParIndicatorView(currentMoves: 15, optimalMoves: 5)
        .padding()
        .background(AppTheme.backgroundSecondary)
}
