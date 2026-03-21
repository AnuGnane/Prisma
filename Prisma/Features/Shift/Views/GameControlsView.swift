//
//  GameControlsView.swift
//  Prisma
//
//  Created by Kiro on Shift game controls view component.
//

import SwiftUI

/// Game controls view containing undo, redo, hint, and reset buttons
/// Provides a horizontal layout of control buttons with proper enabled states
struct GameControlsView: View {
    let canUndo: Bool
    let canRedo: Bool
    let canHint: Bool
    let hintsRemaining: Int
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onHint: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ControlButton(
                label: "Undo",
                icon: "arrow.uturn.backward",
                isEnabled: canUndo,
                action: onUndo
            )
            
            ControlButton(
                label: "Redo",
                icon: "arrow.uturn.forward",
                isEnabled: canRedo,
                action: onRedo
            )
            
            Spacer()
            
            ControlButton(
                label: "Hint",
                icon: "lightbulb",
                badge: hintsRemaining > 0 ? "\(hintsRemaining)" : nil,
                isEnabled: canHint,
                action: onHint
            )
            
            ControlButton(
                label: "Reset",
                icon: "arrow.clockwise",
                isEnabled: true,
                action: onReset
            )
        }
    }
}

// MARK: - Previews

#Preview("All Enabled") {
    GameControlsView(
        canUndo: true,
        canRedo: true,
        canHint: true,
        hintsRemaining: 3,
        onUndo: {},
        onRedo: {},
        onHint: {},
        onReset: {}
    )
    .padding()
    .background(AppTheme.backgroundSecondary)
}

#Preview("Undo/Redo Disabled") {
    GameControlsView(
        canUndo: false,
        canRedo: false,
        canHint: true,
        hintsRemaining: 2,
        onUndo: {},
        onRedo: {},
        onHint: {},
        onReset: {}
    )
    .padding()
    .background(AppTheme.backgroundSecondary)
}

#Preview("No Hints Remaining") {
    GameControlsView(
        canUndo: true,
        canRedo: true,
        canHint: false,
        hintsRemaining: 0,
        onUndo: {},
        onRedo: {},
        onHint: {},
        onReset: {}
    )
    .padding()
    .background(AppTheme.backgroundSecondary)
}

#Preview("Mid-Game State") {
    GameControlsView(
        canUndo: true,
        canRedo: false,
        canHint: true,
        hintsRemaining: 1,
        onUndo: {},
        onRedo: {},
        onHint: {},
        onReset: {}
    )
    .padding()
    .background(AppTheme.backgroundSecondary)
}
