//
//  BalanceBannerCard.swift
//  BoloSplit
//
//  Splitwise-style top balance summary header with animated numeric transitions
//  and a visual owed-vs-owing balance bar.
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

    private var netTint: Color {
        AppTheme.balanceColor(for: summary.netTotal)
    }

    private var owedRatio: Double {
        let owed = NSDecimalNumber(decimal: max(0, summary.totalOwedToYou)).doubleValue
        let owe = NSDecimalNumber(decimal: max(0, summary.totalYouOwe)).doubleValue
        let total = owed + owe
        guard total > 0 else { return 0.5 }
        return owed / total
    }

    private var hasAnyBalance: Bool {
        summary.totalOwedToYou > 0 || summary.totalYouOwe > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: summary.netTotal > 0 ? "arrow.down.left.circle.fill" : (summary.netTotal < 0 ? "arrow.up.right.circle.fill" : "checkmark.seal.fill"))
                    .font(.title3)
                    .foregroundStyle(netTint)
                    .contentTransition(.symbolEffect(.replace))

                Text(headlineText)
                    .font(.headline)
                    .foregroundStyle(netTint)
                    .contentTransition(.numericText())
            }

            if hasAnyBalance {
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        if summary.totalOwedToYou > 0 {
                            Capsule()
                                .fill(AppTheme.owedPositive.gradient)
                                .frame(width: max(8, geo.size.width * owedRatio - (summary.totalYouOwe > 0 ? 1.5 : 0)))
                        }
                        if summary.totalYouOwe > 0 {
                            Capsule()
                                .fill(AppTheme.owedNegative.gradient)
                        }
                    }
                }
                .frame(height: 6)
                .animation(AppMotion.gentle, value: owedRatio)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Owed to you")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatINR(summary.totalOwedToYou))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.owedPositive)
                        .contentTransition(.numericText())
                }

                Divider()
                    .frame(height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text("You owe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatINR(summary.totalYouOwe))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.owedNegative)
                        .contentTransition(.numericText())
                }

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedCardSurface(tint: netTint, cornerRadius: 16)
        .animation(AppMotion.gentle, value: summary)
    }
}
