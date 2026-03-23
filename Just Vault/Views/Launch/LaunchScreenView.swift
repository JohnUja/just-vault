//
//  LaunchScreenView.swift
//  Just Vault
//
//  Loading screen: white background, logo + JUST™ (company) same style/size as sign-in page.
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 14) {
                if let image = UIImage(named: "justvault") {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .shadow(color: AppTheme.accent.opacity(0.25), radius: 10)
                        .scaleEffect(isAnimating ? 1.0 : 0.85)
                        .opacity(showContent ? 1.0 : 0)
                } else {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.accent)
                        .scaleEffect(isAnimating ? 1.0 : 0.85)
                        .opacity(showContent ? 1.0 : 0)
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(AppConfig.companyWordmark)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(AppTheme.headerTint)
                    Text("™")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.secondaryText)
                        .baselineOffset(4)
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

/// Reusable branding block (logo + JUST™ company wordmark) for Terms and sign-in — same as loading screen.
struct KeepBrandingBlock: View {
    var logoSize: CGFloat = 72
    var titleSize: CGFloat = 22

    var body: some View {
        VStack(spacing: 16) {
            if let image = UIImage(named: "justvault") {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: logoSize, height: logoSize)
                    .shadow(color: AppTheme.launchLogoGlow.opacity(0.7), radius: 16)
            } else {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: logoSize * 0.85))
                    .foregroundStyle(AppTheme.launchLogoGlow)
                    .shadow(color: AppTheme.launchLogoGlow.opacity(0.6), radius: 12)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(AppConfig.companyWordmark)
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundColor(.white)
                Text("™")
                    .font(.system(size: titleSize - 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .baselineOffset(4)
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
