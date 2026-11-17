//
//  FriendDetailView.swift
//  BoloSplit
//
//  Splitwise-style 1-on-1 friend detail showing net balance, Settle Up CTA, and shared timeline.
//

import SwiftUI

struct FriendDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var viewModel: FriendDetailViewModel
    @State private var showSettleUp = false

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    ErrorBanner(message: error) {
                        Task { await viewModel.loadFeed() }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                FriendSummaryHeaderCard(
                    friend: viewModel.friend,
                    netBalance: viewModel.netBalance,
                    summaryText: viewModel.feed?.summaryText
                ) {
                    showSettleUp = true
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if viewModel.timeline.isEmpty && !viewModel.isLoading {
                Section {
                    EmptyStateView(
                        systemImage: "arrow.left.arrow.right.circle",
                        title: "No shared history yet",
                        subtitle: "Tap the Bolo mic button and say \"Add 500 dinner split with \(viewModel.friend.name)\" to start."
                    )
                }
                .listRowBackground(Color.clear)
            } else {
                Section("Shared Activity") {
                    ForEach(viewModel.timeline) { item in
                        BilateralTimelineRow(item: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if item.isSettlement {
                                    Button(role: .destructive) {
                                        Task { await viewModel.undoSettlement(id: item.id) }
                                    } label: {
                                        Label("Undo", systemImage: "arrow.uturn.backward")
                                    }
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.friend.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settle Up") {
                    showSettleUp = true
                }
                .fontWeight(.semibold)
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.feed == nil {
                ProgressView("Loading shared history...")
            }
        }
        .refreshable {
            await viewModel.loadFeed()
        }
        .task {
            await viewModel.loadFeed()
        }
        .sheet(isPresented: $showSettleUp) {
            SettleUpSheet(
                viewModel: environment.makeSettleUpViewModel(
                    friendId: viewModel.friend.id,
                    friendName: viewModel.friend.name,
                    netBalance: viewModel.netBalance,
                    onSettled: {
                        await viewModel.loadFeed()
                    }
                )
            )
        }
    }
}

// MARK: - Friend Header Card

private struct FriendSummaryHeaderCard: View {
    let friend: FriendRowItem
    let netBalance: Decimal
    let summaryText: String?
    let onSettleUp: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Circle()
                    .fill(AppTheme.brand.opacity(0.16))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Text(String(friend.name.prefix(1)).uppercased())
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.brand)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.name)
                        .font(.title3.bold())

                    Text(displaySummary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.balanceColor(for: netBalance))

                    if !friend.aliases.isEmpty {
                        Text("Aliases: \(friend.aliases.prefix(3).joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            Button(action: onSettleUp) {
                Label(
                    netBalance < 0 ? "Settle Up Now" : "Record Payment",
                    systemImage: "indianrupeesign.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.brand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var displaySummary: String {
        if let summaryText, !summaryText.isEmpty {
            return summaryText
        }
        if netBalance > 0 {
            return "\(friend.name) owes you \(CurrencyFormatter.formatINR(netBalance))"
        } else if netBalance < 0 {
            return "You owe \(friend.name) \(CurrencyFormatter.formatINR(abs(netBalance)))"
        }
        return "All settled up!"
    }
}

// MARK: - Timeline Row

private struct BilateralTimelineRow: View {
    let item: ActivityTimelineItem

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill((item.isSettlement ? AppTheme.owedPositive : AppTheme.brand).opacity(0.14))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: item.isSettlement ? "checkmark.seal.fill" : "receipt.fill")
                        .foregroundStyle(item.isSettlement ? AppTheme.owedPositive : AppTheme.brand)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.description)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text("\(item.payerName) paid \(CurrencyFormatter.formatINR(item.totalAmount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(impactLabel)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.balanceColor(for: item.yourNetImpact))

                Text(CurrencyFormatter.formatINR(abs(item.yourNetImpact)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.balanceColor(for: item.yourNetImpact))
            }
        }
        .padding(.vertical, 4)
    }

    private var impactLabel: String {
        if item.isSettlement {
            return item.yourNetImpact >= 0 ? "you paid" : "received"
        }
        if item.yourNetImpact > 0 {
            return "you lent"
        } else if item.yourNetImpact < 0 {
            return "you borrowed"
        }
        return "even"
    }
}
