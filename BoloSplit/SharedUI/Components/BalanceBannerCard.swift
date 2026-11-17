//
//  BalanceBannerCard.swift
//  BoloSplit
//
//  Splitwise-style top balance summary header.
//

import SwiftUI

struct BalanceBannerCard: View {
    let summary: BalanceSummary

    private var headlineText: String {
        if summary.netTotal > 0 {
            return "Overall, you are owed \(CurrencyFormatter.formatINR(summary.netTotal))"
        } else if summary.netTotal < 0 {
            return "Overall, you owe \(CurrencyFormatter.formatINR(abs(summary.netTotal)))"
        } else {
            return "Overall, you are all settled up!"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headlineText)
                .font(.headline)
                .foregroundStyle(AppTheme.balanceColor(for: summary.netTotal))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Owed to you")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatINR(summary.totalOwedToYou))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.owedPositive)
                }

                Divider()
                    .frame(height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("You owe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatINR(summary.totalYouOwe))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.owedNegative)
                }

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
