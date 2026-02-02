//
//  Just_VaultApp.swift
//  Just Vault
//
//  Created by John Uja on 2026-01-23.
//

import SwiftUI
import AuthenticationServices

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
                            switch result {
                            case .success(let authorization):
                                // Handle successful authorization
                                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    // Extract user info
                                    let appleUserID = appleIDCredential.user
                                    let email = appleIDCredential.email
                                    let fullName = appleIDCredential.fullName
                                    
                                    // Extract token for future Cognito exchange
                                    // TODO: Use identityToken when implementing Cognito token exchange
                                    _ = appleIDCredential.identityToken
                                    
                                    // For now, create a placeholder user
                                    let name = [fullName?.givenName, fullName?.familyName]
                                        .compactMap { $0 }
                                        .joined(separator: " ")
                                    
                                    let user = User(
                                        id: appleUserID, // Placeholder - will be Cognito Identity ID
                                        appleUserId: appleUserID,
                                        email: email,
                                        name: name.isEmpty ? nil : name,
                                        createdAt: Date(),
                                        lastActiveAt: Date(),
                                        subscriptionTier: .free,
                                        subscriptionStatus: .none,
                                        cloudStorageUsedBytes: 0,
                                        cloudStorageQuotaBytes: Int64(AppConfig.freeTierCloudStorageMB * 1_000_000)
                                    )
                                    
                                    await MainActor.run {
                                        authService.currentUser = user
                                        authService.isAuthenticated = true
                                    }
                                }
                            case .failure(let error):
                                print("Sign in failed: \(error.localizedDescription)")
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
