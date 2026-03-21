//
//  ControlButton.swift
//  Prisma
//
//  Created by Kiro on Shift game control button component.
//

import SwiftUI

/// A control button component for game actions (undo, redo, hint, reset)
/// Follows the Liquid Glass design aesthetic with optional badge overlay
struct ControlButton: View {
    let label: String
    let icon: String
    var badge: String?
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .frame(width: 56, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.12))
                        .opacity(isEnabled ? 1.0 : 0.5)
                )
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(4)
                        .background(Circle().fill(Color.red))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Previews

#Preview("Enabled Button") {
    ControlButton(
        label: "Undo",
        icon: "arrow.uturn.backward",
        isEnabled: true,
        action: {}
    )
    .padding()
    .background(AppTheme.backgroundSecondary)
}

#Preview("Disabled Button") {
    ControlButton(
        label: "Redo",
        icon: "arrow.uturn.forward",
        isEnabled: false,
        action: {}
    )
    .padding()
    .background(AppTheme.backgroundSecondary)
}

#Preview("Button with Badge") {
    ControlButton(
        label: "Hint",
        icon: "lightbulb",
        badge: "3",
        isEnabled: true,
        action: {}
    )
    .padding()
    .background(AppTheme.backgroundSecondary)
}

#Preview("All Control Buttons") {
    HStack(spacing: 16) {
        ControlButton(
            label: "Undo",
            icon: "arrow.uturn.backward",
            isEnabled: true,
            action: {}
        )
        
        ControlButton(
            label: "Redo",
            icon: "arrow.uturn.forward",
            isEnabled: false,
            action: {}
        )
        
        ControlButton(
            label: "Hint",
            icon: "lightbulb",
            badge: "2",
            isEnabled: true,
            action: {}
        )
        
        ControlButton(
            label: "Reset",
            icon: "arrow.clockwise",
            isEnabled: true,
            action: {}
        )
    }
    .padding()
    .background(AppTheme.backgroundSecondary)
}
