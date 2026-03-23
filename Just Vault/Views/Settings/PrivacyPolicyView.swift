//
//  PrivacyPolicyView.swift
//  Just Vault
//
//  Privacy Policy page
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - Bright purple/pink + white gradient (app-wide)
                AppTheme.backgroundGradient.ignoresSafeArea()
                
                ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                    
                    Text("Last updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    
                    SectionView(title: "1. Information We Collect") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(AppConfig.appName) is designed with privacy as a core principle. We collect minimal information necessary to provide our service:")
                            
                            BulletPoint("Account Information: Your Apple ID email (if provided) and name for account management")
                            BulletPoint("File Metadata: File names, sizes, types, timestamps, sync status, and space assignment")
                            BulletPoint("Device Information: Device type and iOS version for compatibility")
                        }
                    }
                    
                    SectionView(title: "2. How We Use Your Information") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("We use the information we collect to:")
                            
                            BulletPoint("Provide and maintain our service")
                            BulletPoint("Provide customer support")
                            BulletPoint("Maintain cloud backup and restore for paid plans")
                            BulletPoint("Detect, prevent and address technical issues")
                        }
                    }
                    
                    SectionView(title: "3. Data Storage and Security") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your files are encrypted locally on your device before cloud upload. For paid plans:")
                            
                            BulletPoint("Files are encrypted before upload to AWS S3")
                            BulletPoint("Metadata is stored in AWS DynamoDB")
                            BulletPoint("We do not have access to your encrypted files")
                            BulletPoint("Free tier users: Files are stored locally only and are not uploaded to the cloud")
                            BulletPoint("Cloud data for v1 is stored in the United States")
                        }
                    }
                    
                    SectionView(title: "4. Third-Party Services") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("We use the following third-party services:")
                            
                            BulletPoint("Apple Sign In: For authentication (subject to Apple's Privacy Policy)")
                            BulletPoint("AWS (Amazon Web Services): For encrypted cloud storage and metadata (paid plans only)")
                            BulletPoint("StoreKit: For in-app purchases (subject to Apple's Privacy Policy)")
                        }
                    }
                    
                    SectionView(title: "5. Your Rights") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You have the right to:")
                            
                            BulletPoint("Access your personal data")
                            BulletPoint("Request deletion of your account and data")
                            BulletPoint("Request deletion of cloud-backed account data")
                            BulletPoint("Request help from support, although we cannot decrypt files for you")
                        }
                    }
                    
                    SectionView(title: "6. Children's Privacy") {
                        Text("Our service is not intended for children under 13. We do not knowingly collect personal information from children under 13.")
                    }
                    
                    SectionView(title: "7. Changes to This Policy") {
                        Text("We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the \"Last Updated\" date.")
                    }
                    
                    SectionView(title: "8. Contact Us") {
                        Text("If you have any questions about this Privacy Policy, contact us at support@juvantage.com or through the Email support option in Settings.")
                    }
                }
                .padding()
                }
            }
            .navigationTitle("Privacy Policy")
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

struct SectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            content
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.accent)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}

