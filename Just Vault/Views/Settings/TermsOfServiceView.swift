//
//  TermsOfServiceView.swift
//  Just Vault
//
//  Terms of Service page
//

import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - Bright purple/pink + white gradient (app-wide)
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
                
                ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Terms of Service")
                        .font(.system(size: 34, weight: .bold))
                        .padding(.top)
                    
                    Text("Last Updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    SectionView(title: "1. Acceptance of Terms") {
                        Text("By accessing and using Just Vault, you accept and agree to be bound by the terms and provision of this agreement.")
                    }
                    
                    SectionView(title: "2. Description of Service") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Just Vault is a secure file storage and management application that allows you to:")
                            
                            BulletPoint("Store and organize files locally on your device")
                            BulletPoint("Encrypt files for security")
                            BulletPoint("Sync files to cloud storage (Pro/Pro+ subscribers)")
                            BulletPoint("Organize files into custom spaces")
                        }
                    }
                    
                    SectionView(title: "3. Subscription Plans") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Just Vault offers the following subscription tiers:")
                            
                            BulletPoint("Free: Local storage only, limited to 3 spaces")
                            BulletPoint("Pro: 10GB cloud storage, unlimited spaces")
                            BulletPoint("Pro+: 50GB cloud storage, unlimited spaces")
                            
                            Text("\nSubscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.")
                        }
                    }
                    
                    SectionView(title: "4. User Responsibilities") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You agree to:")
                            
                            BulletPoint("Use the service only for lawful purposes")
                            BulletPoint("Not upload illegal, harmful, or offensive content")
                            BulletPoint("Maintain the security of your account")
                            BulletPoint("Not attempt to reverse engineer or hack the service")
                        }
                    }
                    
                    SectionView(title: "5. Intellectual Property") {
                        Text("The service and its original content, features, and functionality are owned by Just Vault and are protected by international copyright, trademark, and other intellectual property laws.")
                    }
                    
                    SectionView(title: "6. Limitation of Liability") {
                        Text("Just Vault shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use or inability to use the service.")
                    }
                    
                    SectionView(title: "7. Termination") {
                        Text("We may terminate or suspend your account immediately, without prior notice, for conduct that we believe violates these Terms of Service or is harmful to other users, us, or third parties.")
                    }
                    
                    SectionView(title: "8. Changes to Terms") {
                        Text("We reserve the right to modify these terms at any time. We will notify users of any material changes via the app or email.")
                    }
                    
                    SectionView(title: "9. Refund Policy") {
                        Text("Subscriptions are managed through Apple's App Store. Refunds are subject to Apple's refund policy. Contact Apple Support for refund requests.")
                    }
                    
                    SectionView(title: "10. Contact Information") {
                        Text("For questions about these Terms of Service, please contact us through the app settings or email support.")
                    }
                }
                .padding()
                }
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TermsOfServiceView()
}

