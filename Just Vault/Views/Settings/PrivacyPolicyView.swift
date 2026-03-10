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
                    Text("Privacy Policy")
                        .font(.system(size: 34, weight: .bold))
                        .padding(.top)
                    
                    Text("Last Updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    SectionView(title: "1. Information We Collect") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Just Vault is designed with privacy as a core principle. We collect minimal information necessary to provide our service:")
                            
                            BulletPoint("Account Information: Your Apple ID email (if provided) and name for account management")
                            BulletPoint("Usage Data: Basic app usage statistics to improve our service")
                            BulletPoint("Device Information: Device type and iOS version for compatibility")
                        }
                    }
                    
                    SectionView(title: "2. How We Use Your Information") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("We use the information we collect to:")
                            
                            BulletPoint("Provide and maintain our service")
                            BulletPoint("Notify you about changes to our service")
                            BulletPoint("Provide customer support")
                            BulletPoint("Monitor the usage of our service")
                            BulletPoint("Detect, prevent and address technical issues")
                        }
                    }
                    
                    SectionView(title: "3. Data Storage and Security") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your files are encrypted locally on your device using industry-standard encryption. For Pro and Pro+ subscribers:")
                            
                            BulletPoint("Files are encrypted before upload to AWS S3")
                            BulletPoint("Metadata is stored in AWS DynamoDB")
                            BulletPoint("We do not have access to your encrypted files")
                            BulletPoint("Free tier users: Files are stored locally only, never uploaded to cloud")
                        }
                    }
                    
                    SectionView(title: "4. Third-Party Services") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("We use the following third-party services:")
                            
                            BulletPoint("Apple Sign In: For authentication (subject to Apple's Privacy Policy)")
                            BulletPoint("AWS (Amazon Web Services): For cloud storage (Pro/Pro+ users only)")
                            BulletPoint("StoreKit: For in-app purchases (subject to Apple's Privacy Policy)")
                        }
                    }
                    
                    SectionView(title: "5. Your Rights") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You have the right to:")
                            
                            BulletPoint("Access your personal data")
                            BulletPoint("Request deletion of your account and data")
                            BulletPoint("Opt-out of data collection (by using free tier)")
                            BulletPoint("Export your data at any time")
                        }
                    }
                    
                    SectionView(title: "6. Children's Privacy") {
                        Text("Our service is not intended for children under 13. We do not knowingly collect personal information from children under 13.")
                    }
                    
                    SectionView(title: "7. Changes to This Policy") {
                        Text("We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the \"Last Updated\" date.")
                    }
                    
                    SectionView(title: "8. Contact Us") {
                        Text("If you have any questions about this Privacy Policy, please contact us through the app settings or email support.")
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
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
            
            content
                .font(.system(size: 15))
                .foregroundColor(.secondary)
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
                .foregroundColor(.orange)
            Text(text)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}

