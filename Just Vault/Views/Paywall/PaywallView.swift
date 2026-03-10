//
//  PaywallView.swift
//  Just Vault
//
//  Paywall screen with subscription options - 3 tiers vertically
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeKitService = StoreKitService.shared
    @State private var selectedBilling: BillingPeriod = .monthly
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
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
                    VStack(spacing: 24) {

                        // Header
                        VStack(spacing: 12) {
                            Text("Choose Your Plan")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)

                            Text("Start free, upgrade anytime")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.top, 40)

                        // Billing Period Toggle - strong outline, clear contrast
                        HStack(spacing: 0) {
                            Button {
                                withAnimation { selectedBilling = .monthly }
                            } label: {
                                Text("Monthly")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(selectedBilling == .monthly ? .white : Color(red: 0.32, green: 0.08, blue: 0.42))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        selectedBilling == .monthly
                                        ? LinearGradient(
                                            colors: [Color(red: 0.32, green: 0.08, blue: 0.42), Color(red: 0.38, green: 0.1, blue: 0.48)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        : LinearGradient(
                                            colors: [Color.white.opacity(0.95)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12, corners: [.topLeft, .bottomLeft])
                            }

                            Button {
                                withAnimation { selectedBilling = .yearly }
                            } label: {
                                Text("Yearly")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(selectedBilling == .yearly ? .white : Color(red: 0.32, green: 0.08, blue: 0.42))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        selectedBilling == .yearly
                                        ? LinearGradient(
                                            colors: [Color(red: 0.32, green: 0.08, blue: 0.42), Color(red: 0.38, green: 0.1, blue: 0.48)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        : LinearGradient(
                                            colors: [Color.white.opacity(0.95)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12, corners: [.topRight, .bottomRight])
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.32, green: 0.08, blue: 0.42), lineWidth: 2.5)
                        )
                        .padding(.horizontal, 20)

                        // Plan Cards - Vertical List
                        VStack(spacing: 16) {
                            PlanCard(
                                tier: .free,
                                billing: selectedBilling,
                                isSelected: selectedTier == .free,
                                onSelect: { withAnimation { selectedTier = .free } }
                            )

                            PlanCard(
                                tier: .pro,
                                billing: selectedBilling,
                                isSelected: selectedTier == .pro,
                                onSelect: { withAnimation { selectedTier = .pro } }
                            )

                            PlanCard(
                                tier: .proPlus,
                                billing: selectedBilling,
                                isSelected: selectedTier == .proPlus,
                                onSelect: { withAnimation { selectedTier = .proPlus } }
                            )
                        }
                        .padding(.horizontal, 20)

                        // Subscribe / Continue Button
                        Button {
                            Task { await purchaseSubscription() }
                        } label: {
                            HStack {
                                if isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                }

                                Text(selectedTier == .free ? "Continue with Free" : "Subscribe Now")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedTier == .free
                                ? LinearGradient(
                                    colors: [Color.gray, Color.gray.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color(red: 0.5, green: 0.3, blue: 0.7), Color(red: 0.4, green: 0.2, blue: 0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                            .shadow(
                                color: selectedTier == .free ? Color.clear : Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.3),
                                radius: 12, x: 0, y: 6
                            )
                        }
                        .padding(.horizontal, 20)
                        .disabled(isPurchasing) // ✅ allow "Continue with Free"

                        // Restore Purchases
                        Button {
                            Task { await restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await storeKitService.loadProducts()
            }
        }
    }

    // MARK: - Purchase

    private func purchaseSubscription() async {
        // ✅ free path works + button now allows tapping it
        guard selectedTier != .free else {
            dismiss()
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        guard let product = storeKitService.getProduct(for: selectedTier, billing: selectedBilling) else {
            errorMessage = "Product not available. Please try again later."
            showError = true
            return
        }

        do {
            let transaction = try await storeKitService.purchase(product)
            if transaction != nil {
                // TODO: update user model with new tier
                dismiss()
            }
        } catch {
            if let storeKitError = error as? StoreKitError, storeKitError == .userCancelled {
                return
            }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Restore

    private func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await storeKitService.restorePurchases()
            // TODO: update user model with restored subscription
            dismiss()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let tier: SubscriptionTier
    let billing: BillingPeriod
    let isSelected: Bool
    let onSelect: () -> Void

    // ✅ better than StateObject for a shared singleton
    @ObservedObject private var storeKitService = StoreKitService.shared

    var price: String {
        if let product = storeKitService.getProduct(for: tier, billing: billing) {
            return product.displayPrice
        }

        // Fallback to hardcoded prices
        switch (tier, billing) {
        case (.free, _): return "Free"
        case (.pro, .monthly): return "$6.99/month"
        case (.pro, .yearly): return "$59.99/year"
        case (.proPlus, .monthly): return "$9.99/month"
        case (.proPlus, .yearly): return "$99.99/year"
        }
    }

    var features: [String] {
        switch tier {
        case .free:
            return ["3 Spaces", "Local Storage Only", "No Cloud Backup"]
        case .pro:
            return ["20 Spaces", "10 GB Cloud Storage", "Cloud Backup & Sync", "Locked Spaces"]
        case .proPlus:
            return ["20 Spaces", "50 GB Cloud Storage", "Cloud Backup & Sync", "Locked Spaces", "Priority Support"]
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier.displayName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)

                        Text(price)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    ZStack {
                            Circle()
                                .fill(Color(uiColor: .systemBackground).opacity(0.9))
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? Color(red: 0.32, green: 0.08, blue: 0.42) : Color.gray.opacity(0.4), lineWidth: 2)
                                )
                                .frame(width: 24, height: 24)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(red: 0.32, green: 0.08, blue: 0.42))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 16))
                                .foregroundColor(isSelected ? Color(red: 0.5, green: 0.3, blue: 0.7) : .secondary)

                            Text(feature)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? Color(red: 0.32, green: 0.08, blue: 0.42) : Color.gray.opacity(0.35), lineWidth: 2)
                        )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
}

// Note: RoundedCorner and cornerRadius extension are defined in OnboardingFlowView.swift
