//
//  SubscriptionPlanPickerSection.swift
//  Just Vault
//
//  Shared plan UI: header, billing toggle, tier cards (sign-up, settings paywall, onboarding).
//

import SwiftUI
import StoreKit

// MARK: - Section

struct SubscriptionPlanPickerSection: View {
    @Binding var selectedBilling: BillingPeriod
    @Binding var selectedTier: SubscriptionTier
    /// When `nil` (sign-up before account), "Current" is never shown.
    var currentEffectiveTier: SubscriptionTier?
    /// Extra line under the main subtitle (e.g. paywall: "Upgrade or change anytime").
    var additionalSubtitle: String?

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Text("Choose your plan")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(AppTheme.headerTint)

                Text(planPickerTrialSummary)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

                if let additionalSubtitle, !additionalSubtitle.isEmpty {
                    Text(additionalSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText.opacity(0.92))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)

            CompactBillingPeriodToggle(selectedBilling: $selectedBilling)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                PlanCard(
                    tier: .free,
                    billing: selectedBilling,
                    isSelected: selectedTier == .free,
                    isCurrent: currentEffectiveTier.map { $0 == .free } ?? false,
                    onSelect: { withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { selectedTier = .free } }
                )

                PlanCard(
                    tier: .pro,
                    billing: selectedBilling,
                    isSelected: selectedTier == .pro,
                    isCurrent: currentEffectiveTier.map { $0 == .pro } ?? false,
                    showPopularBadge: true,
                    onSelect: { withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { selectedTier = .pro } }
                )

                PlanCard(
                    tier: .proPlus,
                    billing: selectedBilling,
                    isSelected: selectedTier == .proPlus,
                    isCurrent: currentEffectiveTier.map { $0 == .proPlus } ?? false,
                    onSelect: { withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { selectedTier = .proPlus } }
                )
            }
        }
    }

    /// Monthly: no trial in copy. Yearly: trial only on yearly Pro / Pro+ (must match App Store Connect).
    private var planPickerTrialSummary: String {
        switch selectedBilling {
        case .monthly:
            return "Monthly plans bill right away—no free trial. Yearly includes a \(AppConfig.subscriptionYearlyFreeTrialDays)-day free trial on Pro and Pro+ where eligible."
        case .yearly:
            return "Yearly Pro and Pro+ include a \(AppConfig.subscriptionYearlyFreeTrialDays)-day free trial where eligible. Yearly saves more than monthly."
        }
    }
}

// MARK: - Billing toggle (compact, neutral track)

struct CompactBillingPeriodToggle: View {
    @Binding var selectedBilling: BillingPeriod

    var body: some View {
        HStack(spacing: 4) {
            segment(.monthly, title: "Monthly")
            segment(.yearly, title: "Yearly")
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func segment(_ period: BillingPeriod, title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                selectedBilling = period
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selectedBilling == period ? .white : AppTheme.headerTint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .padding(.horizontal, 6)
                .background(
                    Group {
                        if selectedBilling == period {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppTheme.headerTint,
                                            AppTheme.headerTint.opacity(0.88)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Plan card

struct PlanCard: View {
    let tier: SubscriptionTier
    let billing: BillingPeriod
    let isSelected: Bool
    var isCurrent: Bool = false
    var showPopularBadge: Bool = false
    let onSelect: () -> Void

    @ObservedObject private var storeKitService = StoreKitService.shared

    var price: String {
        if let product = storeKitService.getProduct(for: tier, billing: billing) {
            return product.displayPrice
        }
        switch (tier, billing) {
        case (.free, _): return "Free"
        case (.pro, .monthly): return "$6.99/month"
        case (.pro, .yearly): return "$59.99/year"
        case (.proPlus, .monthly): return "$9.99/month"
        case (.proPlus, .yearly): return "$79.99/year"
        }
    }

    var yearlySavingsPercent: Int? {
        guard billing == .yearly, tier != .free else { return nil }
        switch tier {
        case .free: return nil
        case .pro: return 29
        case .proPlus: return 33
        }
    }

    var features: [String] {
        switch tier {
        case .free:
            return [
                "Up to 6 spaces",
                "Local storage only",
                "No cloud backup",
                "\(AppConfig.maxFileSizeMB(for: .free)) MB max per file",
                "Lock spaces with Face ID"
            ]
        case .pro:
            return [
                "Up to 6 spaces",
                "10 GB cloud storage",
                "Cloud backup & sync",
                "\(AppConfig.maxFileSizeMB(for: .pro)) MB max per file",
                "Locked spaces (Face ID)",
                "Recovery phrase backup"
            ]
        case .proPlus:
            return [
                "Unlimited spaces",
                "50 GB cloud storage",
                "Cloud backup & sync",
                "\(AppConfig.maxFileSizeMB(for: .proPlus)) MB max per file",
                "Locked spaces (Face ID)",
                "Recovery phrase backup",
                "Priority support"
            ]
        }
    }

    private var cardAccent: Color {
        PaywallView.tierAccent(tier)
    }

    private var paidTierBillingFootnote: String {
        switch billing {
        case .monthly:
            return "Billed monthly right away—no free trial. Cancel anytime."
        case .yearly:
            return "Includes a \(AppConfig.subscriptionYearlyFreeTrialDays)-day free trial where eligible, then billed yearly. Cancel anytime."
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(tier.displayName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.headerTint)
                            if showPopularBadge && tier == .pro {
                                Text("POPULAR")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.headerTint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(AppTheme.gold.opacity(0.35)))
                                    .overlay(Capsule().stroke(AppTheme.gold.opacity(0.6), lineWidth: 1))
                            }
                            if isCurrent {
                                Text("Current")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(cardAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(cardAccent.opacity(0.15)))
                            }
                            if let pct = yearlySavingsPercent {
                                Text("Save \(pct)%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.green.opacity(0.9)))
                            }
                        }

                        Text(price)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.secondaryText)

                        if tier != .free {
                            Text(paidTierBillingFootnote)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.secondaryText.opacity(0.95))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 8)

                    ZStack {
                        Circle()
                            .fill(isSelected ? cardAccent.opacity(0.2) : Color.clear)
                            .frame(width: 32, height: 32)
                        Circle()
                            .stroke(isSelected ? cardAccent : Color.gray.opacity(0.4), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(cardAccent)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(features, id: \.self) { feature in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(isSelected ? cardAccent : AppTheme.accent.opacity(0.45))
                            Text(feature)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(AppTheme.headerTint)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    cardAccent.opacity(0.1),
                                    cardAccent.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    AppTheme.cardBackground,
                                    AppTheme.background.opacity(0.98)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? cardAccent.opacity(0.55) : Color.gray.opacity(0.22),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? cardAccent.opacity(0.14) : Color.black.opacity(0.04),
                        radius: isSelected ? 10 : 5,
                        x: 0,
                        y: 3
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
