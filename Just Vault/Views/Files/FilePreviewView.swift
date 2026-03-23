//
//  FilePreviewView.swift
//  Just Vault
//
//  Preview view for decrypting and displaying files.
//  Local is the source of truth: we always load from device storage first; we only
//  download from S3 when the file does not exist locally (e.g. after reinstall).
//

import SwiftUI
import PDFKit
import UIKit

struct FilePreviewView: View {
    let file: VaultFile
    @State private var decryptedData: Data?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Decrypting file...")
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.error)
                        Text("Error")
                            .font(.title2)
                            .bold()
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else if let data = decryptedData {
                    if file.isPDF {
                        PDFPreviewView(data: data)
                    } else if file.isImage {
                        ImagePreviewView(data: data)
                    } else {
                        Text("Preview not available for this file type")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(file.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if decryptedData != nil {
                        Button {
                            shareFile()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }
            }
        }
        .task {
            await decryptFile()
        }
    }
    
    private func shareFile() {
        guard let data = decryptedData else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(file.displayName)
        try? data.write(to: tempURL)
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }

    private func decryptFile() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let localStorage = LocalStorageService()
            let encryptedData: Data

            let didDownloadFromS3: Bool
            if localStorage.fileExists(fileId: file.id) {
                encryptedData = try localStorage.loadEncryptedFile(fileId: file.id)
                didDownloadFromS3 = false
            } else {
                let downloaded = try await S3Service.shared.downloadFile(key: file.s3Key)
                _ = try localStorage.saveEncryptedFile(downloaded, fileId: file.id)
                encryptedData = downloaded
                didDownloadFromS3 = true
            }
            
            // Decrypt using EncryptionService
            let encryptionService = EncryptionService()
            let decrypted = try encryptionService.decryptFile(encryptedData, fileId: file.id)
            
            await MainActor.run {
                decryptedData = decrypted
            }
            
            // Mark as .synced locally after S3 download so list shows green cloud icon; update lastOpenedAt
            let updatedFile = VaultFile(
                id: file.id,
                userId: file.userId,
                spaceId: file.spaceId,
                displayName: file.displayName,
                sizeBytes: file.sizeBytes,
                mimeType: file.mimeType,
                createdAt: file.createdAt,
                lastOpenedAt: Date(),
                starred: file.starred,
                localPath: file.localPath,
                s3Key: file.s3Key,
                syncStatus: .synced,
                version: file.version,
                thumbnailS3Key: file.thumbnailS3Key
            )
            try? LocalFileMetadataService.shared.saveFileMetadata(updatedFile, userId: file.userId)
            if didDownloadFromS3 {
                await MainActor.run {
                    NotificationCenter.default.post(name: .vaultFilesDidChange, object: nil)
                }
            }
            Task {
                try? await DynamoDBService.shared.saveFileMetadata(updatedFile)
                await MainActor.run {
                    NotificationCenter.default.post(name: .vaultFilesDidChange, object: nil)
                }
            }
        } catch {
            let message: String
            if let encError = error as? EncryptionError {
                switch encError {
                case .keyNotFound:
                    message = "Your vault key isn’t on this device. Sign in again to trigger Recovery, then restore using your recovery questions or phrase."
                case .decryptionFailed:
                    message = "We couldn’t decrypt this file. Your vault key on this device doesn’t match the encrypted data. Restore your vault using Recovery, then try again."
                default:
                    message = "We couldn’t decrypt this file. Restore your vault using Recovery, then try again."
                }
            } else if let seError = error as? SecureEnclaveError, seError == .keyNotFound {
                message = "Your vault key isn’t on this device. Sign in again to trigger Recovery, then restore using your recovery questions or phrase."
            } else {
                message = error.localizedDescription
            }
            
            await MainActor.run {
                errorMessage = message
            }
        }
    }
}

// MARK: - PDF Preview

struct PDFPreviewView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // No updates needed
    }
}

// MARK: - Image Preview

struct ImagePreviewView: View {
    let data: Data
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        maxWidth: geometry.size.width,
                        maxHeight: geometry.size.height,
                        alignment: .center
                    )
                    .scaleEffect(scale)
                    .offset(offset)
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                // Limit scale between 1 and 5
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                } else if scale > 5.0 {
                                    withAnimation {
                                        scale = 5.0
                                        lastScale = 5.0
                                    }
                                }
                                if scale <= 1.0 {
                                    withAnimation {
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1.0 else {
                                    offset = .zero
                                    return
                                }
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                if scale > 1.0 {
                                    lastOffset = offset
                                } else {
                                    withAnimation {
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        // Double tap to reset zoom
                        withAnimation {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
            } else {
                Text("Failed to load image")
                    .foregroundColor(.secondary)
            }
        }
    }
}

