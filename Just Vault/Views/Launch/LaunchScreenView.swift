//
//  LaunchScreenView.swift
//  Just Vault
//
//  Launch screen with Just Vault logo
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Background - White (like Just Scan)
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App icon image - center loading icon (smaller, like Just Scan)
                if let image = UIImage(named: "justvault") {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(showContent ? 1.0 : 0)
                } else {
                    // Fallback
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(.orange)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(showContent ? 1.0 : 0)
                }
                
                // App Name with Just™ branding (only "JUST ^TM")
                HStack(spacing: 4) {
                    Text("JUST")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("^")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .baselineOffset(8)
                    
                    Text("TM")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .baselineOffset(8)
                }
                .opacity(showContent ? 1.0 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isAnimating = true
                showContent = true
            }
        }
    }
}

struct OctagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        var path = Path()
        for i in 0..<8 {
            let angle = CGFloat.pi / 4 * CGFloat(i) - CGFloat.pi / 8
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    LaunchScreenView()
}

