//
//  Just_VaultApp.swift
//  Just Vault
//
//  Created by John Uja on 2026-01-23.
//

import SwiftUI

@main
struct Just_VaultApp: App {
    @StateObject private var authService = AuthenticationService()
    
    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                VaultHomeView()
                    .environmentObject(authService)
            } else {
                // Landing/Sign In Screen
                SignInView()
                    .environmentObject(authService)
            }
        }
    }
}

// Placeholder Sign In View
struct SignInView: View {
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.purple)
            
            Text("Just Vault")
                .font(.largeTitle)
                .bold()
            
            Text("Your secure document vault")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if authService.isLoading {
                ProgressView()
            } else {
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        Task {
                            do {
                                try await authService.signInWithApple()
                            } catch {
                                print("Sign in failed: \(error)")
                            }
                        }
                    }
                )
                .frame(height: 50)
                .cornerRadius(8)
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .padding()
    }
}
