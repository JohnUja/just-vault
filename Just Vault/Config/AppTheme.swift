//
//  AppTheme.swift
//  Just Vault
//
//  Single source of truth for app colors.
//  Palette: warm ivory bg, muted teal accent, soft gold highlight, charcoal text.
//

import SwiftUI

enum AppTheme {

    // MARK: - Backgrounds

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.973, green: 0.969, blue: 0.961),   // warm ivory
                Color(red: 0.949, green: 0.945, blue: 0.933)    // slightly deeper ivory
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var background: Color {
        Color(red: 0.973, green: 0.969, blue: 0.961)
    }

    // MARK: - Text

    static var headerTint: Color {
        Color(red: 0.11, green: 0.11, blue: 0.118)              // charcoal
    }

    static var secondaryText: Color {
        Color(red: 0.42, green: 0.42, blue: 0.435)              // medium gray
    }

    static var headerText: Color { .white }

    // MARK: - Accent (teal)

    static var accent: Color {
        Color(red: 0.165, green: 0.486, blue: 0.482)            // muted teal
    }

    static var accentSecondary: Color {
        Color(red: 0.22, green: 0.56, blue: 0.55)               // lighter teal
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSecondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Gold highlight (badges, recommended tags)

    static var gold: Color {
        Color(red: 0.769, green: 0.635, blue: 0.396)            // soft gold
    }

    static var goldLight: Color {
        Color(red: 0.85, green: 0.76, blue: 0.58)
    }

    // MARK: - Outlines / borders

    static var outline: Color {
        accent.opacity(0.25)
    }

    static var outlineStrong: Color {
        accent.opacity(0.6)
    }

    // MARK: - Cards / surfaces

    static var cardBackground: Color {
        Color.white
    }

    static var cardOutline: Color {
        Color.black.opacity(0.06)
    }

    // MARK: - Launch / branding (black welcome screen)

    /// Glowing blue for logo on black (JUST™ welcome/terms screens)
    static var launchLogoGlow: Color {
        Color(red: 0.25, green: 0.55, blue: 1.0)
    }

    // MARK: - Semantic (keep standard for clarity)

    static var success: Color { Color(red: 0.2, green: 0.7, blue: 0.4) }
    static var warning: Color { .orange }
    static var error: Color { .red }
}

extension View {
    func appThemeBackground() -> some View {
        self.background(
            AppTheme.backgroundGradient
                .ignoresSafeArea()
        )
    }
}
