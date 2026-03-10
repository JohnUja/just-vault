//
//  GhostHexagonView.swift
//  Just Vault
//
//  Ghost/empty hexagon slot with + icon
//

import SwiftUI

struct GhostHexagonView: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Dashed outline
                HexagonShape()
                    .stroke(
                        Color.gray.opacity(0.3),
                        style: StrokeStyle(
                            lineWidth: 2,
                            dash: [5, 5]
                        )
                    )
                    .frame(width: 130, height: 130)
                
                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
    }
}



