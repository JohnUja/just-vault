//
//  FileFilterSheet.swift
//  Just Vault
//
//  File sorting/filtering options
//

import SwiftUI

struct FileFilterSheet: View {
    @Binding var sortOption: FileSortOption
    @Environment(\.dismiss) var dismiss
    let onApply: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section("Sort By") {
                    ForEach(FileSortOption.allCases, id: \.self) { option in
                        Button(action: {
                            sortOption = option
                        }) {
                            HStack {
                                Text(option.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sort Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}



