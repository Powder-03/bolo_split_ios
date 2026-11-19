//
//  EmptyStateView.swift
//  BoloSplit
//
//  Reusable empty and error state components with gentle animations.
//

import SwiftUI

struct EmptyStateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let systemImage: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @State private var isFloating = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.brand.opacity(0.10))
                    .frame(width: 84, height: 84)
                    .scaleEffect(isFloating ? 1.06 : 0.96)

                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(AppTheme.brand)
                    .offset(y: isFloating ? -3 : 3)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    isFloating = true
                }
            }

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(AppTheme.brandGradient, in: Capsule())
                        .shadow(color: AppTheme.brand.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(BoloPressButtonStyle(haptic: .light))
                .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .staggeredEntrance()
    }
}

struct ErrorBanner: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Spacer()

            Button("Retry", action: retryAction)
                .font(.footnote.weight(.semibold))
                .buttonStyle(BoloPressButtonStyle(haptic: .light))
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
