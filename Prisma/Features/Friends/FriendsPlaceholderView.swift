//
//  FriendsPlaceholderView.swift
//  Prisma
//
//  "Coming Soon" Friends tab shown until social features are implemented.
//

import SwiftUI

struct FriendsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground()

                VStack(spacing: 20) {
                    Image(systemName: "person.2.fill")
                        .font(.system(.largeTitle, weight: .light))
                        .foregroundStyle(.primary.opacity(0.25))

                    Text("Follow your friends'\ndaily results.")
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Track scores, streaks, and solve times\nacross all Prisma games.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.5))
                        .multilineTextAlignment(.center)

                    Text("COMING SOON")
                        .font(.caption.bold())
                        .foregroundStyle(.primary.opacity(0.4))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 40)
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    FriendsPlaceholderView()
}
