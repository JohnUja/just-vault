//
//  PaywallView.swift
//  Just Vault
//
//  Paywall screen with subscription options — uses shared SubscriptionPlanPickerSection.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var storeKitService = StoreKitService.shared
    @State private var selectedBilling: BillingPeriod = .yearly
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var introOfferEligible = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        SubscriptionPlanPickerSection(
                            selectedBilling: $selectedBilling,
                            selectedTier: $selectedTier,
                            currentEffectiveTier: authService.currentUser?.effectiveTier,
                            additionalSubtitle: "Upgrade or change anytime."
                        )
                        .padding(.top, 20)
                        .padding(.horizontal, 16)

                        Button {
                            Task { await purchaseSubscription() }
                        } label: {
                            HStack {
                                if isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                }

                                Text(primaryCTATitle)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ctaBackground)
                            .cornerRadius(25)
                            .shadow(
                                color: selectedTier == .free ? Color.clear : PaywallView.tierAccent(selectedTier).opacity(0.35),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                        }
                        .padding(.horizontal, 20)
                        .disabled(isPurchasing)

                        Button {
                            Task { await restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 36)
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
                await refreshIntroEligibility()
            }
            .onChange(of: selectedTier) { _, _ in
                Task { await refreshIntroEligibility() }
            }
            .onChange(of: selectedBilling) { _, _ in
                Task { await refreshIntroEligibility() }
            }
        }
    }

    private var primaryCTATitle: String {
        if selectedTier == .free { return "Continue with Free" }
        if introOfferEligible {
            return "Start \(AppConfig.subscriptionYearlyFreeTrialDays)-Day Free Trial"
        }
        return "Subscribe Now"
    }

    @ViewBuilder
    private var ctaBackground: some View {
        if selectedTier == .free {
            LinearGradient(
                colors: [AppTheme.secondaryText, AppTheme.secondaryText.opacity(0.78)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            let c = PaywallView.tierAccent(selectedTier)
            LinearGradient(
                colors: [c, c.opacity(0.72)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private func refreshIntroEligibility() async {
        guard selectedTier != .free else {
            introOfferEligible = false
            return
        }
        introOfferEligible = await storeKitService.isEligibleForIntroductoryOffer(
            tier: selectedTier,
            billing: selectedBilling
        )
    }

    // MARK: - Purchase

    private func purchaseSubscription() async {
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
                await storeKitService.applyResolvedTierToUser(authService: authService)
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
            await storeKitService.applyResolvedTierToUser(authService: authService)
            dismiss()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            showError = true
        }
    }

    /// Plan colors: Free = blue, Pro = orange, Pro+ = purple.
    static func tierAccent(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .free: return Color(red: 0.2, green: 0.45, blue: 0.9)
        case .pro: return Color(red: 0.95, green: 0.6, blue: 0.15)
        case .proPlus: return Color(red: 0.4, green: 0.2, blue: 0.7)
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(AuthenticationService())
}
