//
//  FriendDetailView.swift
//  BoloSplit
//
//  Splitwise-style 1-on-1 friend detail showing net balance, Settle Up CTA, and shared timeline.
//

import SwiftUI
import UIKit

struct FriendDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var viewModel: FriendDetailViewModel
    @State private var showSettleUp = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.feed == nil {
                SkeletonLoadingView(showBannerCard: true, rowCount: 5)
            } else {
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
                            ForEach(Array(viewModel.timeline.enumerated()), id: \.element.id) { index, item in
                                if item.isSettlement {
                                    BilateralTimelineRow(item: item)
                                        .staggeredEntrance(index: index)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                Task { await viewModel.undoSettlement(id: item.id) }
                                            } label: {
                                                Label("Undo", systemImage: "arrow.uturn.backward")
                                            }
                                        }
                                } else {
                                    NavigationLink {
                                        ExpenseDetailView(
                                            viewModel: environment.makeExpenseDetailViewModel(
                                                expenseId: item.id,
                                                knownUserNames: [viewModel.friend.id: viewModel.friend.name],
                                                onChanged: {
                                                    await viewModel.loadFeed()
                                                }
                                            )
                                        )
                                    } label: {
                                        BilateralTimelineRow(item: item)
                                    }
                                    .staggeredEntrance(index: index)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .animation(AppMotion.snappy, value: viewModel.timeline)
            }
        }
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

    private var netTint: Color {
        AppTheme.balanceColor(for: netBalance)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                UserAvatarBadge(
                    name: friend.name,
                    size: 56,
                    ringColor: netBalance == 0 ? AppTheme.brand : netTint
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.name)
                        .font(.title3.bold())

                    Text(displaySummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(netTint)
                        .contentTransition(.numericText())

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
                .padding(.vertical, 13)
                .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: AppTheme.brand.opacity(0.25), radius: 8, y: 4)
            }
            .buttonStyle(BoloPressButtonStyle(haptic: .medium))
        }
        .padding(16)
        .tintedCardSurface(tint: netTint, cornerRadius: 16)
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
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill((item.isSettlement ? AppTheme.owedPositive : AppTheme.brand).opacity(0.14))
                .frame(width: 42, height: 42)
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
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.balanceColor(for: item.yourNetImpact))

                Text(CurrencyFormatter.formatINR(abs(item.yourNetImpact)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.balanceColor(for: item.yourNetImpact))
                    .contentTransition(.numericText())
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
