//
//  ResultOverlayTemplate.swift
//  Prisma
//
//  Shared result overlay used by all game views for completion/gave-up states.
//

import SwiftUI

struct ResultOverlayTemplate<Content: View, Actions: View>: View {
    let style: ResultOverlayStyle
    let header: ResultOverlayHeader
    let stats: [ResultStat]
    @ViewBuilder let content: () -> Content
    @ViewBuilder let actions: () -> Actions
    
    var body: some View {
        Group {
            switch style {
            case .panel:
                panelLayout
            case .fullScreen:
                fullScreenLayout
            }
        }
    }
    
    // MARK: - Panel Style (Signals, Archive, Cargo)
    
    private var panelLayout: some View {
        VStack(spacing: 20) {
            headerView
            
            if !stats.isEmpty {
                statsView
            }
            
            content()
            
            actions()
        }
    }
    
    // MARK: - Full Screen Style (Shift)
    
    private var fullScreenLayout: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 24) {
                headerView
                
                if !stats.isEmpty {
                    statsView
                }
                
                content()
                
                actions()
                    .padding(.horizontal, 20)
            }
            .padding(32)
        }
        .transition(.opacity)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        Group {
            switch header {
            case .iconTitle(let icon, let iconColor, let title):
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                    Text(title)
                        .font(.footnote.weight(.bold).monospaced())
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                
            case .stars(let title, let count):
                AnimatedStarsView(title: title, count: count)
                
            case .titleSubtitle(let title, let subtitle):
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                }
                
            case .custom(let title, let subtitle):
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption.weight(.medium).monospaced())
                            .foregroundStyle(.primary.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.primary.opacity(0.06)))
            }
        }
    }
    
    // MARK: - Stats
    
    private var statsView: some View {
        VStack(spacing: 8) {
            ForEach(stats) { stat in
                HStack {
                    Text(stat.label)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.5))
                    Spacer()
                    if let n = Int(stat.value) {
                        AnimatedScoreView(
                            target: n,
                            duration: 0.9,
                            font: .callout.weight(.bold).monospaced(),
                            color: .primary
                        )
                    } else {
                        Text(stat.value)
                            .font(.callout.weight(.bold).monospaced())
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(style == .fullScreen ? 0.12 : 0.07)))
    }

}

// MARK: - Supporting Types

enum ResultOverlayStyle {
    case panel
    case fullScreen
}

enum ResultOverlayHeader {
    case iconTitle(icon: String, color: Color, title: String)
    /// Sequential animated star pop-in. `count` = filled stars (1–3); default 3.
    case stars(title: String, count: Int = 3)
    case titleSubtitle(title: String, subtitle: String?)
    case custom(title: String, subtitle: String?)
}

struct ResultStat: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

// MARK: - Pre-built Button Styles

struct ResultPrimaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [AppTheme.shift, AppTheme.cascadeBlue],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
        }
    }
}

struct ResultSecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.12)))
        }
    }
}

struct ResultShareButton: View {
    let shareString: String
    
    var body: some View {
        ShareLink(item: shareString) {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [AppTheme.shift, AppTheme.cascadeBlue],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
        }
    }
}
