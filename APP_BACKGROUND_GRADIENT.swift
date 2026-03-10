//
//  APP_BACKGROUND_GRADIENT.swift
//  Just Vault
//
//  Shared background gradient for entire app (bright purple/pink + white)
//

import SwiftUI

extension View {
    /// App-wide background gradient (bright purple/pink + white)
    /// Use this on every page except the loading screen
    func appBackgroundGradient() -> some View {
        self.background(
            LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.5, blue: 0.9), // Bright purple/pink
                    Color(red: 0.8, green: 0.4, blue: 0.85), // Medium purple/pink
                    Color.white.opacity(0.9), // White
                    Color(red: 0.85, green: 0.45, blue: 0.9).opacity(0.8) // Light purple/pink
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

