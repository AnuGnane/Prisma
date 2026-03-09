//
//  TargetWordChip.swift
//  Prisma
//
//  Created by Kiro on 2024
//

import SwiftUI

/// A chip component that displays a target word with completion and hint reveal status.
/// Shows different styling based on whether the word is completed or revealed by a hint.
///
/// **Validates: Requirements 5.3, 25.1**
struct TargetWordChip: View {
    
    // MARK: - Properties
    
    /// The word to display
    let word: String
    
    /// Whether this word has been completed
    let isCompleted: Bool
    
    /// Whether this word has been revealed by a hint
    let isRevealed: Bool
    
    // MARK: - Body
    
    var body: some View {
        Text(word)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(isCompleted ? .white : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isCompleted ?
                        Color(hex: "#4A90E2") :
                        Color(hex: "#1E1E2E")
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isRevealed ? Color.yellow.opacity(0.8) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .overlay(
                isCompleted ?
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .offset(x: 8, y: -8)
                : nil,
                alignment: .topTrailing
            )
    }
}

// MARK: - Preview

#Preview("Incomplete") {
    TargetWordChip(
        word: "SHIFT",
        isCompleted: false,
        isRevealed: false
    )
    .padding()
    .background(Color(hex: "#12121A"))
}

#Preview("Completed") {
    TargetWordChip(
        word: "SHIFT",
        isCompleted: true,
        isRevealed: false
    )
    .padding()
    .background(Color(hex: "#12121A"))
}

#Preview("Revealed by Hint") {
    TargetWordChip(
        word: "PUZZLE",
        isCompleted: false,
        isRevealed: true
    )
    .padding()
    .background(Color(hex: "#12121A"))
}

#Preview("Completed and Revealed") {
    TargetWordChip(
        word: "WORDS",
        isCompleted: true,
        isRevealed: true
    )
    .padding()
    .background(Color(hex: "#12121A"))
}
