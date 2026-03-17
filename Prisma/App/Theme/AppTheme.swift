//
//  AppTheme.swift
//  Prisma
//
//  Centralized design tokens for the entire app.
//  All colors defined once; backgrounds adapt to light/dark mode.
//

import SwiftUI

// MARK: - Adaptive Color Helper

extension Color {
    /// Creates a dynamic color that adapts to light/dark mode automatically.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light:  "sun.max.fill"
        case .dark:   "moon.fill"
        }
    }
}

// MARK: - Theme Tokens

enum AppTheme {

    // MARK: Game Accents (constant across modes)

    static let signals = Color(red: 0.24, green: 0.65, blue: 0.36)
    static let archive = Color(red: 0.24, green: 0.52, blue: 0.85)
    static let cargo   = Color(red: 1.00, green: 0.55, blue: 0.26)
    static let shift   = Color(red: 0.65, green: 0.24, blue: 0.85)

    static func accent(for game: GameType) -> Color {
        switch game {
        case .signals: signals
        case .archive: archive
        case .cargo:   cargo
        case .shift:   shift
        case .orbit:   shift
        }
    }

    // MARK: Brand

    static let cascadeBlue = Color(red: 0.4, green: 0.6, blue: 1.0)
    static let brandGradient: [Color] = [shift, cascadeBlue]

    // MARK: Semantic

    static let error = Color(red: 0.85, green: 0.30, blue: 0.30)
    static let deleteRed = Color(red: 1.0, green: 0.45, blue: 0.45)
    static let misplacedWarm   = Color(red: 0.80, green: 0.65, blue: 0.14)
    static let misplacedBright = Color(red: 0.95, green: 0.77, blue: 0.06)

    // MARK: Adaptive Backgrounds

    static let background = Color(
        light: Color(red: 0.96, green: 0.96, blue: 0.98),
        dark:  Color(red: 0.05, green: 0.05, blue: 0.08)
    )

    static let backgroundSecondary = Color(
        light: Color(red: 0.93, green: 0.93, blue: 0.96),
        dark:  Color(red: 0.07, green: 0.07, blue: 0.10)
    )

    static let gradientAccent = Color(
        light: Color(red: 0.82, green: 0.76, blue: 0.95).opacity(0.25),
        dark:  Color(red: 0.15, green: 0.08, blue: 0.30).opacity(0.4)
    )

    // MARK: Adaptive UI Surfaces

    /// Subtle cell/card fill — visible in both modes
    static let cellFill = Color(
        light: Color.black.opacity(0.08),
        dark:  Color.white.opacity(0.06)
    )

    /// Medium fill for interactive elements (buttons, keys)
    static let keyFill = Color(
        light: Color.black.opacity(0.12),
        dark:  Color.white.opacity(0.10)
    )

    /// Counter pill / chip background
    static let pillFill = Color(
        light: Color.black.opacity(0.14),
        dark:  Color.white.opacity(0.12)
    )

    /// Cell/container border
    static let cellBorder = Color(
        light: Color.black.opacity(0.18),
        dark:  Color.white.opacity(0.10)
    )

    /// Subtle structural border
    static let borderSubtle = Color(
        light: Color.black.opacity(0.10),
        dark:  Color.white.opacity(0.05)
    )

    /// Dimmed/disabled text
    static let dimText = Color(
        light: Color.black.opacity(0.38),
        dark:  Color.white.opacity(0.22)
    )

    /// Very dim placeholder text
    static let placeholderText = Color(
        light: Color.black.opacity(0.28),
        dark:  Color.white.opacity(0.15)
    )

    // MARK: Background View Helper

    /// Standard app background: solid color + radial gradient accent.
    static func appBackground() -> some View {
        ZStack {
            background
            RadialGradient(
                colors: [gradientAccent, .clear],
                center: .top, startRadius: 50, endRadius: 500
            )
        }
        .ignoresSafeArea()
    }
}
