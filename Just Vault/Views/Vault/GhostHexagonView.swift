//
//  GhostHexagonView.swift
//  Just Vault
//
//  Ghost/empty hexagon slot
//

import SwiftUI

struct GhostHexagonView: View {
    var hexSide: CGFloat = 120
    let onTap: () -> Void

    private var k: CGFloat { hexSide / 120 }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                HexagonShape()
                    .stroke(
                        AppTheme.outline,
                        style: StrokeStyle(lineWidth: 1.5 * k, dash: [6 * k, 4 * k])
                    )
                    .frame(width: hexSide, height: hexSide)
                
                Image(systemName: "plus")
                    .font(.system(size: 20 * k, weight: .light))
                    .foregroundColor(AppTheme.secondaryText.opacity(0.5))
            }
        }
    }
}
