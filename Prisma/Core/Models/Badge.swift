//
//  Badge.swift
//  Prisma
//
//  Defines all in-app achievement badges and their metadata.
//

import SwiftUI

enum Badge: String, CaseIterable, Identifiable {
    // First wins
    case firstWin          = "first_win"
    
    // Streak milestones
    case streak3           = "streak_3"
    case streak7           = "streak_7"
    case streak30          = "streak_30"
    
    // Performance
    case perfectSignal     = "perfect_signal"
    case speedDemon        = "speed_demon"
    
    // Local mastery
    case local25           = "local_25"
    case local50           = "local_50"
    case local100          = "local_100"
    
    // Completionist (per game)
    case signalsMaster     = "signals_master"
    case archiveMaster     = "archive_master"
    case shiftMaster       = "shift_master"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .firstWin:       return "First Steps"
        case .streak3:        return "On a Roll"
        case .streak7:        return "Week Warrior"
        case .streak30:       return "Unstoppable"
        case .perfectSignal:  return "Perfect Signal"
        case .speedDemon:     return "Speed Demon"
        case .local25:        return "Quarter Century"
        case .local50:        return "Halfway There"
        case .local100:       return "Century Club"
        case .signalsMaster:  return "Signals Master"
        case .archiveMaster:  return "Archive Master"
        case .shiftMaster:    return "Shift Master"
        }
    }
    
    var description: String {
        switch self {
        case .firstWin:       return "Win your first game"
        case .streak3:        return "Achieve a 3-day daily streak"
        case .streak7:        return "Achieve a 7-day daily streak"
        case .streak30:       return "Achieve a 30-day daily streak"
        case .perfectSignal:  return "Crack a Signals code on the first guess"
        case .speedDemon:     return "Solve any level in under 30 seconds"
        case .local25:        return "Win 25 local levels across all games"
        case .local50:        return "Win 50 local levels across all games"
        case .local100:       return "Win 100 local levels across all games"
        case .signalsMaster:  return "Win all 100 Signals local levels"
        case .archiveMaster:  return "Win all 100 Archive local levels"
        case .shiftMaster:    return "Win all 100 Shift local levels"
        }
    }
    
    var iconName: String {
        switch self {
        case .firstWin:       return "star.fill"
        case .streak3:        return "flame.fill"
        case .streak7:        return "flame.fill"
        case .streak30:       return "flame.circle.fill"
        case .perfectSignal:  return "antenna.radiowaves.left.and.right"
        case .speedDemon:     return "bolt.fill"
        case .local25:        return "flag.fill"
        case .local50:        return "flag.2.crossed.fill"
        case .local100:       return "trophy.fill"
        case .signalsMaster:  return "antenna.radiowaves.left.and.right"
        case .archiveMaster:  return "clock.arrow.circlepath"
        case .shiftMaster:    return "slider.horizontal.3"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .firstWin:                          return .yellow
        case .streak3:                           return .orange
        case .streak7:                           return .orange
        case .streak30:                          return .red
        case .perfectSignal, .signalsMaster:     return AppTheme.signals
        case .speedDemon:                        return .cyan
        case .local25, .local50, .local100:      return .purple
        case .archiveMaster:                     return AppTheme.archive
        case .shiftMaster:                       return AppTheme.shift
        }
    }
}

struct BadgeInfo: Identifiable {
    let badge: Badge
    let isUnlocked: Bool
    let unlockedDate: Date?
    
    var id: String { badge.id }
}
