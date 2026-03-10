//
//  AddFileSpaceSelectorView.swift
//  Just Vault
//
//  Space selector when adding a file
//

import SwiftUI

struct AddFileSpaceSelectorView: View {
    let spaces: [Space]
    @Environment(\.dismiss) var dismiss
    let onSpaceSelected: (Space) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(spaces) { space in
                    Button(action: {
                        onSpaceSelected(space)
                        dismiss()
                    }) {
                        HStack(spacing: 16) {
                            // Space icon
                            ZStack {
                                Circle()
                                    .fill(Color(hex: space.color))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: space.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(space.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("\(space.fileCount) files")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}




