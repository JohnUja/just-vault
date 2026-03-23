//
//  CloudBackupBar.swift
//  Just Vault
//
//  Persistent cloud backup notification bar
//

import SwiftUI

struct CloudBackupBar: View {
    let tier: SubscriptionTier
    let usedMB: Double
    let quotaMB: Double
    let backupEnabled: Bool
    var isSyncing: Bool = false
    /// When false and backup is on, show "Up to date" instead of "Sync Now" so the bar isn't always prompting.
    var hasPendingSync: Bool = true
    let onBackup: () -> Void
    
    private var usagePercent: Double {
        guard quotaMB > 0 else { return 0 }
        return min(usedMB / quotaMB, 1.0)
    }
    
    private var barTint: Color {
        if usagePercent > AppConfig.storageCriticalThreshold { return AppTheme.error }
        if usagePercent > AppConfig.storageWarningThreshold { return AppTheme.warning }
        return AppTheme.success
    }
    
    private var warningText: String? {
        if usagePercent > AppConfig.storageCriticalThreshold {
            return "Almost full -- consider upgrading or removing files"
        }
        if usagePercent > AppConfig.storageWarningThreshold {
            return "Running low on cloud storage"
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if tier != .free {
                proBar
            } else {
                freeBar
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.outline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Pro bar with progress + thresholds
    
    private var proBar: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cloud Storage")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.headerTint)
                    
                    Text(isSyncing ? "Syncing…" : remainingText)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                Spacer()
                
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.9)
                        .padding(.trailing, 4)
                } else if backupEnabled && !hasPendingSync {
                    Text("Up to date")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.success)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.success, lineWidth: 1.5))
                        .cornerRadius(20)
                } else {
                    Button(action: onBackup) {
                        Text(backupEnabled ? "Sync Now" : "Turn On Auto Backup")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.success)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.success, lineWidth: 1.5))
                            .cornerRadius(20)
                    }
                }
            }
            
            ProgressView(value: usagePercent)
                .tint(barTint)
            
            if let warning = warningText {
                Text(warning)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(usagePercent > AppConfig.storageCriticalThreshold ? AppTheme.error : AppTheme.warning)
            }
        }
    }
    
    // MARK: - Free bar (upgrade only, no meter)
    
    private var freeBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Backup Your Files")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.headerTint)
                
                Text("Upgrade to Pro to securely backup to the cloud")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onBackup) {
                Text("Upgrade")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.success)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.success, lineWidth: 1.5))
                    .cornerRadius(20)
            }
        }
    }
    
    private var remainingText: String {
        if !backupEnabled {
            return "Automatic cloud backup is off."
        }
        let remaining = max(0, quotaMB - usedMB)
        if remaining >= 1000 {
            return String(format: "%.1f GB remaining", remaining / 1000)
        }
        return "\(Int(remaining)) MB remaining"
    }
}
