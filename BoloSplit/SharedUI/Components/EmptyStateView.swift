//
//  EmptyStateView.swift
//  BoloSplit
//
//  Reusable empty and error state components.
//

import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.brand.opacity(0.8))

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.brand)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorBanner: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Spacer()

            Button("Retry", action: retryAction)
                .font(.footnote.weight(.semibold))
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}
