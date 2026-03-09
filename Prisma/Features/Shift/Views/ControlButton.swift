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
    let icon: String
    var badge: String?
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isEnabled ? .white : .secondary)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#1E1E2E"))
                            .opacity(isEnabled ? 1.0 : 0.5)
                    )
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
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
        icon: "arrow.uturn.backward",
        isEnabled: true,
        action: {}
    )
    .padding()
    .background(Color(hex: "#12121A"))
}

#Preview("Disabled Button") {
    ControlButton(
        icon: "arrow.uturn.forward",
        isEnabled: false,
        action: {}
    )
    .padding()
    .background(Color(hex: "#12121A"))
}

#Preview("Button with Badge") {
    ControlButton(
        icon: "lightbulb",
        badge: "3",
        isEnabled: true,
        action: {}
    )
    .padding()
    .background(Color(hex: "#12121A"))
}

#Preview("All Control Buttons") {
    HStack(spacing: 16) {
        ControlButton(
            icon: "arrow.uturn.backward",
            isEnabled: true,
            action: {}
        )
        
        ControlButton(
            icon: "arrow.uturn.forward",
            isEnabled: false,
            action: {}
        )
        
        ControlButton(
            icon: "lightbulb",
            badge: "2",
            isEnabled: true,
            action: {}
        )
        
        ControlButton(
            icon: "arrow.clockwise",
            isEnabled: true,
            action: {}
        )
    }
    .padding()
    .background(Color(hex: "#12121A"))
}
