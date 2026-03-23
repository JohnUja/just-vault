//
//  WelcomeAndTermsFlowView.swift
//  Just Vault
//
//  First launch: Welcome (logo + Keep™) then Terms accept (same branding, summary, full terms link).
//

import SwiftUI

private let termsAcceptedKey = "hasAcceptedTermsAndConditions"

enum TermsAcceptance {
    static var hasAccepted: Bool {
        get { UserDefaults.standard.bool(forKey: termsAcceptedKey) }
        set { UserDefaults.standard.set(newValue, forKey: termsAcceptedKey) }
    }
}

struct WelcomeAndTermsFlowView: View {
    @Binding var hasAcceptedTerms: Bool
    @State private var phase: Phase = .welcome
    @State private var showFullTerms = false

    enum Phase {
        case welcome
        case terms
    }

    var body: some View {
        ZStack {
                Color.black.ignoresSafeArea()

            switch phase {
            case .welcome:
                LaunchScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                phase = .terms
                            }
                        }
                    }
            case .terms:
                termsAcceptView
            }
        }
        .sheet(isPresented: $showFullTerms) {
            TermsOfServiceView()
        }
    }

    private var termsAcceptView: some View {
        ScrollView {
            VStack(spacing: 0) {
                KeepBrandingBlock(logoSize: 56, titleSize: 18)
                    .padding(.top, 32)

                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms & Conditions")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)

                    Text("By using \(AppConfig.appName) you agree to our Terms of Service and privacy practices. Your files are encrypted on your device and we do not read your data. Cloud backup is optional and uses your account and storage limits.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        showFullTerms = true
                    } label: {
                        HStack {
                            Text("Read full terms")
                                .font(.system(size: 16, weight: .medium))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(AppTheme.launchLogoGlow)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 28)

                Spacer(minLength: 48)

                Button {
                    UserDefaults.standard.set(true, forKey: termsAcceptedKey)
                    hasAcceptedTerms = true
                } label: {
                    Text("I Accept")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
        }
        .background(Color.black)
    }
}
