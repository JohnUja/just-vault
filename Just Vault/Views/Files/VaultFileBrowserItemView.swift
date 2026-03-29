//
//  VaultFileBrowserItemView.swift
//  Just Vault
//
//  Reusable file item for grid/list browsers.
//

import SwiftUI

enum VaultFileBrowserMode {
    case grid
    case list
}

struct VaultFileBrowserItemView: View {
    let file: VaultFile
    let mode: VaultFileBrowserMode
    let isPro: Bool
    let onOpen: () -> Void
    let onPreview: () -> Void
    let onMove: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    var onCloudUpload: (() -> Void)? = nil
    var onCloudDelete: (() -> Void)? = nil
    var onUpgradeTapped: (() -> Void)? = nil
    
    var body: some View {
        Group {
            switch mode {
            case .grid:
                gridCard
            case .list:
                listRow
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen()
        }
        .contextMenu {
            Button(action: onPreview) {
                Label("Preview", systemImage: "eye")
            }
            
            Button(action: onMove) {
                Label("Move To", systemImage: "folder")
            }
            
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            
            Divider()
            
            if isPro {
                if file.syncStatus == .synced {
                    Button(action: { onCloudDelete?() }) {
                        Label("Remove from Cloud", systemImage: "icloud.slash")
                    }
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Grid Card (wide rectangle: full column width × fixed height — same silhouette as early grid, without overlap bugs)

    private static let gridPreviewHeight: CGFloat = 118

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                VaultFileThumbnailView(file: file, cornerRadius: 0)
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()

                syncBadge
                    .padding(6)
            }
            .frame(maxWidth: .infinity, minHeight: Self.gridPreviewHeight, maxHeight: Self.gridPreviewHeight)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
            )

            Text(displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.headerTint)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Text(formattedDate)
                Text("·")
                Text(fileSize)
            }
            .font(.system(size: 10))
            .foregroundColor(AppTheme.secondaryText)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    // MARK: - List Row
    
    private var listRow: some View {
        HStack(spacing: 14) {
            VaultFileThumbnailView(file: file, cornerRadius: 8)
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.headerTint)
                    .lineLimit(1)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
                
                Text(fileSize)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
            
            syncBadge
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.outline.opacity(0.35), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Sync Badge (when Free tier, show all files as local-only so UI reflects no cloud access)
    
    @ViewBuilder
    private var syncBadge: some View {
        if !isPro {
            Image(systemName: "iphone")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.8))
        } else {
            switch file.syncStatus {
            case .synced:
                Image(systemName: "checkmark.icloud.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.success)
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.warning)
            case .error:
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.error)
            case .localOnly:
                Image(systemName: "iphone")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.8))
            case .pending:
                Image(systemName: "icloud")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
    }
    
    // MARK: - Helpers
    
    private var displayName: String {
        let ext = file.fileExtension
        if ext.isEmpty { return file.displayName }
        return file.displayName.replacingOccurrences(of: ".\(ext)", with: "")
    }
    
    private var fileSize: String {
        if file.sizeBytes < 1_000_000 {
            return "\(max(1, file.sizeBytes / 1_000)) KB"
        }
        return String(format: "%.1f MB", file.sizeMB)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(file.createdAt) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .none
        }
        return formatter.string(from: file.createdAt)
    }
}
