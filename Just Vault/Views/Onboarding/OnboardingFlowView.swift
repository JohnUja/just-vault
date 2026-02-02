//
//  OnboardingFlowView.swift
//  Just Vault
//
//  Onboarding flow with paywall and subscription selection
//

import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentStep = 0
    @State private var selectedTier: SubscriptionTier = .free
    @State private var selectedBilling: BillingPeriod = .monthly
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "007AFF").opacity(0.1), Color(hex: "5856D6").opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
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
                Text("Just Vault")
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

// MARK: - Paywall Screen

struct PaywallOnboardingView: View {
    @Binding var selectedTier: SubscriptionTier
    @Binding var selectedBilling: BillingPeriod
    let onContinue: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Choose Your Plan")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Start free, upgrade anytime")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                
                // Billing Period Toggle
                BillingPeriodToggle(selectedBilling: $selectedBilling)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                
                // Tier Selection
                VStack(spacing: 16) {
                    // Free Tier Card
                    TierCard(
                        tier: .free,
                        isSelected: selectedTier == .free,
                        billing: selectedBilling,
                        onSelect: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTier = .free
                            }
                        }
                    )
                    
                    // Pro Tier Card
                    TierCard(
                        tier: .pro,
                        isSelected: selectedTier == .pro,
                        billing: selectedBilling,
                        onSelect: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTier = .pro
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)
                
                // Feature Comparison
                FeatureComparisonView()
                    .padding(.top, 30)
                    .padding(.horizontal, 20)
                
                // CTA Button
                Button(action: onContinue) {
                    HStack {
                        if selectedTier == .pro {
                            Text(selectedBilling == .monthly ? "$6.99/month" : "$59.99/year")
                                .font(.headline)
                        } else {
                            Text("Continue with Free")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        selectedTier == .pro
                            ? LinearGradient(
                                colors: [Color(hex: "007AFF"), Color(hex: "5856D6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [Color.gray, Color.gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Billing Period Toggle

struct BillingPeriodToggle: View {
    @Binding var selectedBilling: BillingPeriod
    
    var body: some View {
        HStack(spacing: 0) {
            // Monthly
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    selectedBilling = .monthly
                }
            }) {
                VStack(spacing: 4) {
                    Text("Monthly")
                        .font(.headline)
                        .foregroundColor(selectedBilling == .monthly ? .white : .primary)
                    
                    Text("$6.99/mo")
                        .font(.caption)
                        .foregroundColor(selectedBilling == .monthly ? .white.opacity(0.9) : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedBilling == .monthly ? Color(hex: "007AFF") : Color.clear)
                .cornerRadius(12, corners: [.topLeft, .bottomLeft])
            }
            
            // Yearly
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    selectedBilling = .yearly
                }
            }) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Yearly")
                            .font(.headline)
                        Text("SAVE 29%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "FF9500"))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .foregroundColor(selectedBilling == .yearly ? .white : .primary)
                    
                    Text("$4.99/mo")
                        .font(.caption)
                        .foregroundColor(selectedBilling == .yearly ? .white.opacity(0.9) : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedBilling == .yearly ? Color(hex: "007AFF") : Color.clear)
                .cornerRadius(12, corners: [.topRight, .bottomRight])
            }
        }
        .background(Color(uiColor: .systemGray5))
        .cornerRadius(12)
    }
}

enum BillingPeriod {
    case monthly
    case yearly
}

// MARK: - Tier Card

struct TierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let billing: BillingPeriod
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier == .free ? "Free" : "Pro")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if tier == .pro {
                            Text(billing == .monthly ? "$6.99/month" : "$59.99/year")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Forever free")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color(hex: "007AFF") : Color.clear)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color(hex: "007AFF") : Color.gray, lineWidth: 2)
                            )
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                
                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    if tier == .free {
                        TierFeature(icon: "checkmark.circle.fill", text: "250 MB cloud storage", color: .green)
                        TierFeature(icon: "checkmark.circle.fill", text: "2 spaces", color: .green)
                        TierFeature(icon: "checkmark.circle.fill", text: "Unlimited local storage", color: .green)
                        TierFeature(icon: "xmark.circle.fill", text: "No cloud backup", color: .red)
                        TierFeature(icon: "xmark.circle.fill", text: "No device restore", color: .red)
                    } else {
                        TierFeature(icon: "checkmark.circle.fill", text: "10 GB cloud storage", color: .green)
                        TierFeature(icon: "checkmark.circle.fill", text: "Unlimited spaces", color: .green)
                        TierFeature(icon: "checkmark.circle.fill", text: "Cloud backup & sync", color: .green)
                        TierFeature(icon: "checkmark.circle.fill", text: "Device restore", color: .green)
                        TierFeature(icon: "checkmark.circle.fill", text: "Keychain recovery", color: .green)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: isSelected ? Color(hex: "007AFF").opacity(0.3) : Color.black.opacity(0.1), radius: isSelected ? 10 : 5, x: 0, y: isSelected ? 5 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "007AFF") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TierFeature: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Feature Comparison

struct FeatureComparisonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's the difference?")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ComparisonRow(feature: "Cloud Storage", free: "250 MB", pro: "10 GB")
                ComparisonRow(feature: "Spaces", free: "2", pro: "Unlimited")
                ComparisonRow(feature: "Cloud Backup", free: "❌", pro: "✅")
                ComparisonRow(feature: "Device Restore", free: "❌", pro: "✅")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemGray6))
        )
    }
}

struct ComparisonRow: View {
    let feature: String
    let free: String
    let pro: String
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.body)
                .foregroundColor(.primary)
                .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            Text(free)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .center)
            
            Text(pro)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "007AFF"))
                .frame(width: 80, alignment: .center)
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
                            .background(Color(hex: "34C759"))
                            .foregroundColor(.white)
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

