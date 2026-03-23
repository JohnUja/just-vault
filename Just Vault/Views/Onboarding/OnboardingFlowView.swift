//
//  OnboardingFlowView.swift
//  Just Vault
//
//  Onboarding flow with paywall and subscription selection
//

import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentStep = 0
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var selectedBilling: BillingPeriod = .yearly
    
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            
            TabView(selection: $currentStep) {
                // Step 1: Welcome
                WelcomeOnboardingView(onContinue: {
                    withAnimation {
                        currentStep = 1
                    }
                })
                .tag(0)
                
                // Step 2: Paywall
                PaywallOnboardingView(
                    selectedTier: $selectedTier,
                    selectedBilling: $selectedBilling,
                    onContinue: {
                        withAnimation {
                            currentStep = 2
                        }
                    }
                )
                .tag(1)
                
                // Step 3: Recovery Setup (only if Pro)
                RecoverySetupView(onContinue: {
                    // Complete onboarding
                })
                .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}

// MARK: - Welcome Screen

struct WelcomeOnboardingView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App Icon/Logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "007AFF"), Color(hex: "5856D6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: Color(hex: "007AFF").opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 16) {
                Text(AppConfig.appName)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Your secure document vault")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Feature highlights
            VStack(spacing: 20) {
                FeatureRow(icon: "lock.fill", text: "Zero-knowledge encryption")
                FeatureRow(icon: "bolt.fill", text: "Instant local access")
                FeatureRow(icon: "icloud.fill", text: "Secure cloud backup")
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // CTA Button
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "007AFF"), Color(hex: "5856D6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(hex: "007AFF"))
                .frame(width: 24)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Paywall Screen (same plan UI as Settings)

struct PaywallOnboardingView: View {
    @Binding var selectedTier: SubscriptionTier
    @Binding var selectedBilling: BillingPeriod
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SubscriptionPlanPickerSection(
                    selectedBilling: $selectedBilling,
                    selectedTier: $selectedTier,
                    currentEffectiveTier: nil,
                    additionalSubtitle: "You can change your plan later in Settings."
                )
                .padding(.horizontal, 16)
                .padding(.top, 44)

                Button(action: onContinue) {
                    Text(onboardingCTATitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(onboardingCTABackground)
                        .cornerRadius(25)
                        .shadow(
                            color: selectedTier == .free ? Color.clear : PaywallView.tierAccent(selectedTier).opacity(0.3),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
        .task {
            await StoreKitService.shared.loadProducts()
        }
    }

    /// Onboarding does not run StoreKit here; paid selection is intent only until the user subscribes in-app.
    private var onboardingCTATitle: String {
        if selectedTier == .free { return "Continue with Free" }
        return "Continue with \(selectedTier.displayName)"
    }

    @ViewBuilder
    private var onboardingCTABackground: some View {
        if selectedTier == .free {
            LinearGradient(
                colors: [AppTheme.secondaryText, AppTheme.secondaryText.opacity(0.78)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            let c = PaywallView.tierAccent(selectedTier)
            LinearGradient(colors: [c, c.opacity(0.72)], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Recovery Setup (Pro only)

struct RecoverySetupView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "key.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(hex: "007AFF"))
            
            VStack(spacing: 16) {
                Text("Enable Recovery")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Restore your vault on any device using your Apple ID")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 16) {
                RecoveryOptionCard(
                    icon: "key.icloud.fill",
                    title: "Apple Keychain Recovery",
                    description: "Automatic • Face ID protected",
                    isRecommended: true
                )
                
                RecoveryOptionCard(
                    icon: "key.fill",
                    title: "Offline Recovery Key",
                    description: "Optional • Extra backup",
                    isRecommended: false
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Set Up Recovery")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "007AFF"), Color(hex: "5856D6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
    }
}

struct RecoveryOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let isRecommended: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(hex: "007AFF"))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if isRecommended {
                        Text("RECOMMENDED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .foregroundColor(Color(hex: "007AFF"))
                            .background(Capsule().fill(Color.clear))
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "007AFF"), lineWidth: 1.5)
                            )
                            .cornerRadius(4)
                    }
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - Extensions
// Note: Color.init(hex:) extension is defined in VaultHomeView.swift

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    OnboardingFlowView()
}

