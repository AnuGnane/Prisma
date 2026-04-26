//
//  AppEmptyState.swift
//  Prisma
//
//  Standardised empty-state and error-state surface used across the app.
//  Wraps `ContentUnavailableView` with consistent padding, theme-aware
//  tinting, and an optional retry action so every "nothing here yet" or
//  "couldn't load" view speaks with one voice.
//
//  Style:
//    • .neutral — no data yet, dimText icon, accent-tinted action
//    • .error   — load failure, AppTheme.error icon + button tint
//
//  Usage:
//
//      // Empty
//      AppEmptyState(
//          systemImage: "trophy",
//          title: "No scores yet",
//          message: "Be the first on the board."
//      )
//
//      // Error with retry
//      AppEmptyState(
//          systemImage: "wifi.exclamationmark",
//          title: "Couldn't load scores",
//          message: "Check your connection and try again.",
//          style: .error,
//          actionTitle: "Retry",
//          action: { Task { await reload() } }
//      )
//

import SwiftUI

struct AppEmptyState: View {

    enum Style {
        /// "Nothing here yet" — neutral tint.
        case neutral
        /// Load failure / disconnected — uses `AppTheme.error` accent.
        case error
    }

    let systemImage: String
    let title: String
    let message: String?
    let style: Style
    let actionTitle: String
    let action: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String? = nil,
        style: Style = .neutral,
        actionTitle: String = "Try again",
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.style = style
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(iconTint)
            }
        } description: {
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } actions: {
            if let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(buttonTint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Styling

    private var iconTint: Color {
        switch style {
        case .neutral: return AppTheme.dimText
        case .error:   return AppTheme.error
        }
    }

    private var buttonTint: Color {
        switch style {
        case .neutral: return .accentColor
        case .error:   return AppTheme.error
        }
    }
}

// MARK: - Previews

#Preview("Neutral, no action") {
    AppEmptyState(
        systemImage: "trophy",
        title: "No scores yet",
        message: "Be the first to post a daily score."
    )
}

#Preview("Error with retry") {
    AppEmptyState(
        systemImage: "wifi.exclamationmark",
        title: "Couldn't load scores",
        message: "Check your connection and try again.",
        style: .error,
        actionTitle: "Retry",
        action: { print("retry") }
    )
}

#Preview("Long message") {
    AppEmptyState(
        systemImage: "person.2.slash",
        title: "No friends yet",
        message: "Add friends in Game Center to compare daily scores, see who's on a streak, and track head-to-head wins across all five games."
    )
}
