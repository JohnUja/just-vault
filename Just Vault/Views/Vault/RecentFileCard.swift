//
//  RecentFileCard.swift
//  Just Vault
//
//  Recent file preview card for homepage (like JustScan)
//

import SwiftUI

struct RecentFileCard: View {
    let file: VaultFile
    @State private var showPreview = false
    
    var body: some View {
        Button(action: {
            showPreview = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    VaultFileThumbnailView(file: file, cornerRadius: 12)
                        .frame(width: 82, height: 96)
                        .clipped()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1.25)
                        )

                    Image(systemName: file.isImage ? "photo" : (file.isPDF ? "doc.richtext" : "doc.text"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.success)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.96))
                        )
                        .padding(6)
                }

                Text(file.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.headerTint)
                    .lineLimit(2)
                    .frame(width: 82, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPreview) {
            FilePreviewView(file: file)
        }
    }
}

