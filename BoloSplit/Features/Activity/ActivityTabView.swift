//
//  ActivityTabView.swift
//  BoloSplit
//
//  Splitwise-style Activity tab showing recent expenses & settlements.
//

import SwiftUI

struct ActivityTabView: View {
    @Bindable var viewModel: ActivityTabViewModel

    var body: some View {
        NavigationStack {
            List {
                if let error = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: error) {
                            Task { await viewModel.loadActivity() }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if viewModel.entries.isEmpty && !viewModel.isLoading {
                    Section {
                        EmptyStateView(
                            systemImage: "clock.arrow.circlepath",
                            title: "No activity yet",
                            subtitle: "Your voice expenses and settlements will appear here in chronological order."
                        )
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section("Recent Activity") {
                        ForEach(viewModel.entries) { entry in
                            ActivityRow(entry: entry)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Activity")
            .overlay {
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    ProgressView("Loading activity...")
                }
            }
            .refreshable {
                await viewModel.loadActivity()
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }
}

private struct ActivityRow: View {
    let entry: ActivityFeedEntry

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill((entry.isSettlement ? AppTheme.owedPositive : AppTheme.brand).opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: entry.isSettlement
                          ? "checkmark.seal.fill"
                          : AppTheme.categoryIcon(for: entry.category))
                        .foregroundStyle(entry.isSettlement ? AppTheme.owedPositive : AppTheme.brand)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(CurrencyFormatter.formatINR(entry.amount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(entry.isSettlement ? AppTheme.owedPositive : .primary)
        }
        .padding(.vertical, 4)
    }
}
