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
        NavigationStack {
            ZStack {
                // Background - Bright purple/pink + white gradient (app-wide)
                AppTheme.backgroundGradient.ignoresSafeArea()
                
                ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Service")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                    
                    Text("Last updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    
                    SectionView(title: "1. Acceptance of Terms") {
                        Text("By downloading, installing, or using \(AppConfig.appName) (the \"App\"), you accept and agree to be bound by these Terms of Service (\"Terms\"). If you do not agree, do not use the App. Your use of the App constitutes acceptance of these Terms and our Privacy Policy.")
                    }
                    
                    SectionView(title: "2. Description of Service") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(AppConfig.appName) is a secure file storage and management application that allows you to:")
                            BulletPoint("Store and organize files locally on your device")
                            BulletPoint("Encrypt files before they are stored or synced")
                            BulletPoint("Sync encrypted files to cloud storage on paid plans")
                            BulletPoint("Organize files into spaces and manage access (e.g. Face ID / Touch ID)")
                            Text("\nAccount creation is required to use the App (e.g. Sign in with Apple). Your vault and encryption keys are tied to your account.")
                        }
                    }
                    
                    SectionView(title: "3. Subscription Plans and Limits") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(AppConfig.appName) offers the following subscription tiers:")
                            BulletPoint("Free: Local storage only; 6 spaces; 25 MB max per file")
                            BulletPoint("Pro: 10 GB cloud storage; 6 spaces; 100 MB max per file; cloud backup and sync")
                            BulletPoint("Pro+: 50 GB cloud storage; unlimited spaces; 500 MB max per file; cloud backup and sync; priority support")
                            Text("\nSubscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. You may manage or cancel subscriptions in your Apple ID subscription settings.")
                        }
                    }
                    
                    SectionView(title: "4. User Responsibilities") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You agree to:")
                            BulletPoint("Use the service only for lawful purposes and in compliance with applicable laws")
                            BulletPoint("Not upload, store, or share illegal, harmful, offensive, or prohibited content")
                            BulletPoint("Maintain the security of your account credentials and recovery materials")
                            BulletPoint("Not attempt to reverse engineer, decompile, or hack the service or circumvent security")
                            BulletPoint("Not resell or commercially exploit the service without authorization")
                        }
                    }
                    
                    SectionView(title: "5. Intellectual Property") {
                        Text("The App, its design, code, features, and branding (including \"\(AppConfig.appName)\" and \"\(AppConfig.companyWordmark)™\") are owned by \(AppConfig.companyWordmark) or its licensors and are protected by copyright, trademark, and other intellectual property laws. You do not acquire any ownership by using the App.")
                    }
                    
                    SectionView(title: "6. Limitation of Liability") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("To the maximum extent permitted by law, \(AppConfig.companyWordmark) shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or for loss of data, revenue, or profits.")
                            Text("We are not responsible for lost access to encrypted data where a device is lost, reset, or replaced, or where recovery materials were not preserved. You are responsible for backing up your recovery phrase and for enabling cloud backup if you want data restored on a new device.")
                        }
                    }
                    
                    SectionView(title: "7. Termination") {
                        Text("We may terminate or suspend your account or access to the App immediately, without prior notice, for conduct that we believe violates these Terms or is harmful to others or the service. Upon termination, your right to use the App ceases. Provisions that by their nature should survive (e.g. limitation of liability, intellectual property) will survive.")
                    }

                    SectionView(title: "8. Recovery and Backup Responsibility") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You are solely responsible for keeping your recovery phrase and any backup of your encryption keys in a safe and accessible place. We recommend backing up your recovery key to the cloud (in-app) and keeping a copy offline.")
                            Text("We may help confirm whether your account or encrypted cloud data exists, but we cannot guarantee restoration of access to your vault if the required recovery path is unavailable.")
                        }
                    }
                    
                    SectionView(title: "9. Privacy and Data") {
                        Text("Your use of the App is also governed by our Privacy Policy. File contents are encrypted on your device; we do not have access to the plaintext of your files. Account and usage data are handled as described in the Privacy Policy. By using the App you consent to such processing.")
                    }
                    
                    SectionView(title: "10. Changes to Terms") {
                        Text("We reserve the right to modify these Terms at any time. We will notify users of material changes via the App or by email where appropriate. Continued use of the App after changes constitutes acceptance of the revised Terms.")
                    }
                    
                    SectionView(title: "11. Refund Policy") {
                        Text("Subscriptions are managed through the Apple App Store. Refunds are subject to Apple's refund policy. Contact Apple Support for refund requests. \(AppConfig.companyWordmark) does not process refunds directly.")
                    }

                    SectionView(title: "12. Data Location and Cloud Storage") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("For the current version, paid cloud backups are stored in the United States. Removing a synced file from cloud storage removes the cloud copy but may leave a local encrypted copy on your device unless you delete it there as well.")
                        }
                    }
                    
                    SectionView(title: "13. Age and Eligibility") {
                        Text("You must be at least 13 years of age (or the minimum age in your jurisdiction) to use the App. By using the App you represent that you meet this requirement and have the authority to enter into these Terms.")
                    }
                    
                    SectionView(title: "14. Governing Law and Disputes") {
                        Text("These Terms are governed by the laws of the United States and the state in which \(AppConfig.companyWordmark) operates, without regard to conflict of law principles. Any dispute arising from these Terms or the App shall be resolved in the courts of that jurisdiction, to the extent permitted by law.")
                    }
                    
                    SectionView(title: "15. Entire Agreement") {
                        Text("These Terms, together with the Privacy Policy and any in-app policies, constitute the entire agreement between you and \(AppConfig.companyWordmark) regarding the App and supersede any prior agreements.")
                    }
                    
                    SectionView(title: "16. Contact Information") {
                        Text("For questions about these Terms of Service, privacy, account deletion, or data requests, please contact us through the app settings or via the support contact provided in the App Store listing.")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 40)
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

