//
//  CloudBackupBar.swift
//  Just Vault
//
//  Persistent cloud backup notification bar
//

import SwiftUI

struct CloudBackupBar: View {
    let isPro: Bool
    let usedMB: Double
    let quotaMB: Double
    let onBackup: () -> Void
    
    var usagePercent: Double {
        guard quotaMB > 0 else { return 0 }
        return min(usedMB / quotaMB, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if isPro {
                // Pro: Show storage remaining
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cloud Storage")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(Int(quotaMB - usedMB)) MB remaining")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    ProgressView(value: usagePercent)
                        .tint(usagePercent > 0.9 ? .red : .blue)
                        .frame(width: 100)
                    
                    Button(action: onBackup) {
                        Text("Backup Now")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.32, green: 0.08, blue: 0.42), Color(red: 0.38, green: 0.1, blue: 0.48)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                    }
                }
            } else {
                // Free: Encourage backup
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Backup Your Files")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Upgrade to Pro to securely backup your files to the cloud")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Button(action: onBackup) {
                        Text("Upgrade")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.5, green: 0.3, blue: 0.7), Color(red: 0.4, green: 0.2, blue: 0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.32, green: 0.08, blue: 0.42), lineWidth: 1.5)
                )
        )
        .padding(.horizontal)
    }
}



