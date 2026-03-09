//
//  MoveHistoryPanel.swift
//  Prisma
//
//  Created by Kiro on 2024.
//

import SwiftUI

/// Collapsible panel displaying the history of moves made by the player
/// Shows numbered move list with descriptions and highlights the most recent move
///
/// **Validates Requirements: 34.1, 34.2, 34.3, 34.4, 34.5**
struct MoveHistoryPanel: View {
    let moves: [ShiftMove]
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header button with chevron
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("MOVE HISTORY")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .kerning(1)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Collapsible move list
            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(moves.enumerated()), id: \.offset) { index, move in
                            HStack {
                                // Move number (1-indexed)
                                Text("\(index + 1).")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                                
                                // Move description (e.g., "Row 1 ←")
                                Text(move.description)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(index == moves.count - 1 ? .white : .secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1E1E2E"))
        )
    }
}

// MARK: - Previews

#Preview("Empty History") {
    MoveHistoryPanel(moves: [])
        .padding()
        .background(Color(hex: "#12121A"))
}

#Preview("Few Moves") {
    MoveHistoryPanel(moves: [
        .rowLeft(0),
        .columnDown(2),
        .rowRight(3)
    ])
        .padding()
        .background(Color(hex: "#12121A"))
}

#Preview("Many Moves") {
    MoveHistoryPanel(moves: [
        .rowLeft(0),
        .columnDown(2),
        .rowRight(3),
        .columnUp(1),
        .rowLeft(4),
        .columnDown(0),
        .rowRight(2),
        .columnUp(3),
        .rowLeft(1),
        .columnDown(4)
    ])
        .padding()
        .background(Color(hex: "#12121A"))
}

#Preview("Expanded State") {
    MoveHistoryPanelPreview()
}

// Helper view for expanded state preview
private struct MoveHistoryPanelPreview: View {
    @State private var moves: [ShiftMove] = [
        .rowLeft(0),
        .columnDown(2),
        .rowRight(3),
        .columnUp(1),
        .rowLeft(4)
    ]
    
    var body: some View {
        VStack {
            MoveHistoryPanel(moves: moves)
            
            Button("Add Move") {
                moves.append(.rowRight(Int.random(in: 0...4)))
            }
            .padding()
        }
        .padding()
        .background(Color(hex: "#12121A"))
    }
}
