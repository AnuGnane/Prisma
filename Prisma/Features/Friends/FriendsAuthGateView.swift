//
//  FriendsAuthGateView.swift
//  Prisma
//
//  Shown when Game Center is unauthenticated or friend permission is not yet
//  granted. Presents the appropriate CTA for each auth state.
//

import SwiftUI
import GameKit

struct FriendsAuthGateView: View {
    let state: FriendsService.FriendsAuthState
    let onRequestAccess: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(.primary.opacity(0.25))

            VStack(spacing: 8) {
                Text(headline)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(subheadline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: onRequestAccess) {
                Text(buttonLabel)
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.primary))
                    .foregroundStyle(Color(uiColor: .systemBackground))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Per-state copy

    private var icon: String {
        switch state {
        case .unknown, .notDetermined: return "person.2.circle"
        case .authorized:              return "person.2.fill"
        case .denied, .restricted:     return "lock.circle"
        }
    }

    private var headline: String {
        switch state {
        case .unknown:       return "Game Center required"
        case .notDetermined: return "See your friends' progress"
        case .authorized:    return "Loading friends…"
        case .denied:        return "Friends access denied"
        case .restricted:    return "Friends not available"
        }
    }

    private var subheadline: String {
        switch state {
        case .unknown:
            return "Sign in to Game Center in Settings to connect with friends and compare scores."
        case .notDetermined:
            return "Allow Prisma to access your Game Center friends to track daily results, streaks, and head-to-head stats."
        case .authorized:
            return "Fetching your Game Center friends list."
        case .denied:
            return "Enable Friends access for Prisma in Settings → Privacy & Security → Game Center."
        case .restricted:
            return "Friends features are restricted on this device."
        }
    }

    private var buttonLabel: String {
        switch state {
        case .unknown:       return "Open Settings"
        case .notDetermined: return "Allow Friends Access"
        case .authorized:    return "Retry"
        case .denied, .restricted: return "Open Settings"
        }
    }
}
