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

// Launch Screen - shown on app start
struct LaunchScreenWrapper: View {
    @State private var showLaunch = true
    @StateObject private var authService = AuthenticationService()
    
    var body: some View {
        Group {
            if showLaunch {
                LaunchScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showLaunch = false
                            }
                        }
                    }
            } else {
                if authService.isAuthenticated {
                    VaultHomeView()
                        .environmentObject(authService)
                } else {
                    SignInView()
                        .environmentObject(authService)
                }
            }
        }
    }
}

// Placeholder Sign In View
struct SignInView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var selectedBilling: BillingPeriod = .yearly // Default to yearly (recommended)
    @State private var selectedTier: SubscriptionTier = .pro // Default to Pro (recommended) - Pro yearly is recommended
    
    var body: some View {
        ZStack {
            // Background - royal/wine purple
            LinearGradient(
                colors: [
                    Color(red: 0.32, green: 0.08, blue: 0.42),
                    Color(red: 0.38, green: 0.1, blue: 0.48),
                    Color(red: 0.28, green: 0.06, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // App icon
                    if let image = UIImage(named: "justvault") {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                    } else {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Just Vault")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Your secure document vault")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Upgrade Options Preview (before sign in) - Scrollable inside box
                    VStack(spacing: 16) {
                        Text("Choose Your Plan")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // Monthly/Yearly Toggle - strong outline, clear contrast
                        HStack(spacing: 0) {
                            Button {
                                withAnimation { selectedBilling = .monthly }
                            } label: {
                                Text("Monthly")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selectedBilling == .monthly ? .white : .white.opacity(0.9))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedBilling == .monthly
                                        ? Color(red: 0.32, green: 0.08, blue: 0.42)
                                        : Color.white.opacity(0.15)
                                    )
                                    .cornerRadius(8, corners: [.topLeft, .bottomLeft])
                            }
                            
                            Button {
                                withAnimation { selectedBilling = .yearly }
                            } label: {
                                Text("Yearly")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selectedBilling == .yearly ? .white : .white.opacity(0.9))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedBilling == .yearly
                                        ? Color(red: 0.32, green: 0.08, blue: 0.42)
                                        : Color.white.opacity(0.15)
                                    )
                                    .cornerRadius(8, corners: [.topRight, .bottomRight])
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                        )
                        .cornerRadius(8)
                        
                        // Scrollable plan cards inside the box
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                // Free Plan Card
                                PlanPreviewCard(
                                    title: "Free",
                                    price: "Free Forever",
                                    features: ["3 Spaces", "Local Storage", "250 MB Cloud"],
                                    color: Color.white.opacity(0.2),
                                    isSelected: selectedTier == .free,
                                    onSelect: { selectedTier = .free }
                                )
                                
                                // Pro Plan Card (Recommended) - Default selection
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("RECOMMENDED")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(red: 0.8, green: 0.4, blue: 0.9))
                                            .cornerRadius(4)
                                        Spacer()
                                    }
                                    PlanPreviewCard(
                                        title: "Pro",
                                        price: selectedBilling == .monthly ? "$6.99/month" : "$59.99/year",
                                        features: ["Unlimited Spaces", "10 GB Cloud", "Cloud Backup"],
                                        color: Color(red: 0.8, green: 0.4, blue: 0.9).opacity(0.6),
                                        isSelected: selectedTier == .pro,
                                        onSelect: { selectedTier = .pro }
                                    )
                                }
                                
                                // Pro+ Plan Card
                                PlanPreviewCard(
                                    title: "Pro+",
                                    price: selectedBilling == .monthly ? "$9.99/month" : "$99.99/year",
                                    features: ["Unlimited Spaces", "50 GB Cloud", "Priority Support"],
                                    color: Color(red: 0.8, green: 0.4, blue: 0.9).opacity(0.8),
                                    isSelected: selectedTier == .proPlus,
                                    onSelect: { selectedTier = .proPlus }
                                )
                            }
                        }
                        .frame(maxHeight: 400) // Limit height for scrolling
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(red: 0.8, green: 0.4, blue: 0.9), lineWidth: 2) // Bright purple/pink outline
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.clear)
                            )
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    if authService.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        VStack(spacing: 12) {
                            // Sign in/up button - text changes based on user state
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
                                                
                                                // If user selected a plan, initiate purchase
                                                if selectedTier != .free {
                                                    // TODO: Present StoreKit purchase sheet for selected plan
                                                    // For now, create user with selected tier (will be updated after purchase)
                                                    print("User selected \(selectedTier) plan - purchase flow to be implemented")
                                                }
                                                
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
                                                    subscriptionTier: .free, // Will be updated after purchase
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
                            .signInWithAppleButtonStyle(.white)
                            
                            // Show button text based on whether user exists
                            Text(authService.currentUser != nil ? "Sign In with Apple" : "Sign Up with Apple")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                }
                .padding(.vertical, 40)
            }
        }
    }
}

// Plan Preview Card for Login Screen
struct PlanPreviewCard: View {
    let title: String
    let price: String
    let features: [String]
    let color: Color
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            onSelect?()
        }) {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(price)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                        Text(feature)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected 
                        ? Color(red: 0.8, green: 0.4, blue: 0.9) 
                        : Color(red: 0.5, green: 0.3, blue: 0.7), 
                    lineWidth: isSelected ? 3 : 2
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color(red: 0.8, green: 0.4, blue: 0.9).opacity(0.2) : Color.clear)
                )
        )
        }
    }
}

// Blur View Helper
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// Note: cornerRadius extension and RoundedCorner are defined in OnboardingFlowView.swift
