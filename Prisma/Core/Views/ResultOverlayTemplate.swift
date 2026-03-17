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
                        .font(.system(size: 24))
                        .foregroundStyle(iconColor)
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                
            case .stars(let title):
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.yellow)
                        }
                    }
                    Text(title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
            case .titleSubtitle(let title, let subtitle):
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                }
                
            case .custom(let title, let subtitle):
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                    Spacer()
                    Text(stat.value)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
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
    case stars(title: String)
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
                .font(.system(size: 17, weight: .bold))
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
                .font(.system(size: 17, weight: .bold))
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
                .font(.system(size: 17, weight: .semibold))
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
