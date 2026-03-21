//
//  BadgeGridView.swift
//  Prisma
//
//  Displays achievement badges in a grid. Unlocked badges glow;
//  locked badges are dimmed. Tap for detail sheet.
//

import SwiftUI

struct BadgeGridView: View {
    let badges: [BadgeInfo]
    let unlockedCount: Int
    let totalCount: Int
    
    @State private var selectedBadge: BadgeInfo?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACHIEVEMENTS")
                    .font(.caption2.weight(.heavy).monospaced())
                    .foregroundStyle(.secondary)
                    .kerning(1.5)
                
                Spacer()
                
                Text("\(unlockedCount)/\(totalCount)")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(.primary.opacity(0.4))
            }
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(badges) { info in
                    Button {
                            selectedBadge = info
                    } label: {
                        badgeCell(info)
                        }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(info.badge.title)
                    .accessibilityValue(info.isUnlocked ? "Unlocked" : "Locked")
                    .accessibilityHint("Shows badge details")
                }
            }
        }
        .sheet(item: $selectedBadge) { info in
            badgeDetailSheet(info)
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func badgeCell(_ info: BadgeInfo) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(info.isUnlocked
                          ? info.badge.accentColor.opacity(0.15)
                          : Color.primary.opacity(0.04))
                    .frame(width: 52, height: 52)
                
                if info.isUnlocked {
                    Circle()
                        .strokeBorder(info.badge.accentColor.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 52, height: 52)
                }
                
                Image(systemName: info.badge.iconName)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(info.isUnlocked ? info.badge.accentColor : .primary.opacity(0.15))
            }
            
            Text(info.badge.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(info.isUnlocked ? Color.primary.opacity(0.7) : Color.primary.opacity(0.2))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }
    
    private func badgeDetailSheet(_ info: BadgeInfo) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(info.isUnlocked
                          ? info.badge.accentColor.opacity(0.15)
                          : Color.primary.opacity(0.04))
                    .frame(width: 80, height: 80)
                
                if info.isUnlocked {
                    Circle()
                        .strokeBorder(info.badge.accentColor.opacity(0.5), lineWidth: 2)
                        .frame(width: 80, height: 80)
                }
                
                Image(systemName: info.badge.iconName)
                    .font(.largeTitle.weight(.medium))
                    .foregroundStyle(info.isUnlocked ? info.badge.accentColor : .primary.opacity(0.2))
            }
            .padding(.top, 20)
            
            Text(info.badge.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(info.isUnlocked ? .white : .primary.opacity(0.4))
            
            Text(info.badge.description)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.5))
                .multilineTextAlignment(.center)
            
            if info.isUnlocked, let date = info.unlockedDate {
                Text("Unlocked \(date.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .font(.caption.weight(.medium).monospaced())
                    .foregroundStyle(info.badge.accentColor.opacity(0.7))
            } else {
                Text("LOCKED")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(.primary.opacity(0.2))
                    .kerning(2)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.backgroundSecondary)
    }
}

#Preview {
    let sampleBadges = Badge.allCases.enumerated().map { idx, badge in
        BadgeInfo(badge: badge, isUnlocked: idx < 4, unlockedDate: idx < 4 ? .now : nil)
    }
    return BadgeGridView(badges: sampleBadges, unlockedCount: 4, totalCount: Badge.allCases.count)
        .padding()
        .background(AppTheme.backgroundSecondary)
}
