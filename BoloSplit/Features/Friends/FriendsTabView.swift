//
//  FriendsTabView.swift
//  BoloSplit
//
//  Splitwise-style Friends tab: top net summary + clean per-friend balance list.
//

import SwiftUI

struct FriendsTabView: View {
    @Bindable var viewModel: FriendsTabViewModel

    var body: some View {
        NavigationStack {
            List {
                if let error = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: error) {
                            Task { await viewModel.loadData() }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if let summary = viewModel.balanceSummary {
                    Section {
                        BalanceBannerCard(summary: summary)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if viewModel.friendRows.isEmpty && !viewModel.isLoading {
                    Section {
                        EmptyStateView(
                            systemImage: "person.2.fill",
                            title: "No friends yet",
                            subtitle: "Add a friend or tap the mic to split your first expense."
                        )
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section("Friends") {
                        ForEach(viewModel.friendRows) { friend in
                            FriendBalanceRow(friend: friend)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Friends")
            .overlay {
                if viewModel.isLoading && viewModel.balanceSummary == nil {
                    ProgressView("Loading balances...")
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .task {
                if viewModel.balanceSummary == nil {
                    await viewModel.loadData()
                }
            }
        }
    }
}

private struct FriendBalanceRow: View {
    let friend: FriendRowItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.brand.opacity(0.15))
                .frame(width: 42, height: 42)
                .overlay {
                    Text(String(friend.name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundStyle(AppTheme.brand)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.body.weight(.medium))

                if let nickname = friend.nickname, !nickname.isEmpty, nickname.lowercased() != friend.name.lowercased() {
                    Text("aka \(nickname)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if friend.netBalance > 0 {
                    Text("owes you")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.owedPositive)
                    Text(CurrencyFormatter.formatINR(friend.netBalance))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.owedPositive)
                } else if friend.netBalance < 0 {
                    Text("you owe")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.owedNegative)
                    Text(CurrencyFormatter.formatINR(abs(friend.netBalance)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.owedNegative)
                } else {
                    Text("settled up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
