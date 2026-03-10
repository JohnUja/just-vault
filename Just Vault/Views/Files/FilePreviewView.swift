//
//  FilePreviewView.swift
//  Just Vault
//
//  Preview view for decrypting and displaying files
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
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Decrypting file...")
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await decryptFile()
        }
    }
    
    private func decryptFile() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load encrypted file from local storage
            let localStorage = LocalStorageService()
            let encryptedData = try localStorage.loadEncryptedFile(fileId: file.id)
            
            // Decrypt using EncryptionService
            let encryptionService = EncryptionService()
            let decrypted = try encryptionService.decryptFile(encryptedData, fileId: file.id)
            
            await MainActor.run {
                decryptedData = decrypted
            }
            
            // Update lastOpenedAt in DynamoDB (don't block UI)
            Task {
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
                    syncStatus: file.syncStatus,
                    version: file.version,
                    thumbnailS3Key: file.thumbnailS3Key
                )
                try? await DynamoDBService.shared.saveFileMetadata(updatedFile)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
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
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
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
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
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

