//
//  FriendsTabView.swift
//  BoloSplit
//
//  Splitwise-style Friends tab: top net summary, animated filter pills, search,
//  and polished per-friend balance list.
//

import SwiftUI

private enum FriendBalanceFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case owedToYou = "Owed to you"
    case youOwe = "You owe"
    case settled = "Settled"

    var id: String { rawValue }
}

struct FriendsTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var viewModel: FriendsTabViewModel
    @State private var showAddFriend = false
    @State private var searchText = ""
    @State private var filter: FriendBalanceFilter = .all
    @Namespace private var filterNamespace

    private var filteredFriends: [FriendRowItem] {
        viewModel.friendRows.filter { friend in
            let matchesFilter: Bool = {
                switch filter {
                case .all: return true
                case .owedToYou: return friend.netBalance > 0
                case .youOwe: return friend.netBalance < 0
                case .settled: return friend.netBalance == 0
                }
            }()

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return matchesFilter }

            let matchesName = friend.name.localizedCaseInsensitiveContains(query)
            let matchesNickname = friend.nickname?.localizedCaseInsensitiveContains(query) ?? false
            let matchesAlias = friend.aliases.contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesFilter && (matchesName || matchesNickname || matchesAlias)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.balanceSummary == nil {
                    SkeletonLoadingView(showBannerCard: true, rowCount: 5)
                } else {
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

                        if !viewModel.friendRows.isEmpty {
                            Section {
                                filterChipStrip
                            }
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                            .listRowBackground(Color.clear)
                        }

                        if viewModel.friendRows.isEmpty && !viewModel.isLoading {
                            Section {
                                EmptyStateView(
                                    systemImage: "person.2.fill",
                                    title: "No friends yet",
                                    subtitle: "Add a friend, then speak to Bolo to split your first expense.",
                                    actionTitle: "Add Friend"
                                ) {
                                    showAddFriend = true
                                }
                            }
                            .listRowBackground(Color.clear)
                        } else if filteredFriends.isEmpty {
                            Section {
                                EmptyStateView(
                                    systemImage: "magnifyingglass",
                                    title: "No matching friends",
                                    subtitle: "Try adjusting your search or balance filter."
                                )
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            Section("Friends (\(filteredFriends.count))") {
                                ForEach(Array(filteredFriends.enumerated()), id: \.element.id) { index, friend in
                                    NavigationLink {
                                        FriendDetailView(
                                            viewModel: environment.makeFriendDetailViewModel(friend: friend)
                                        )
                                    } label: {
                                        FriendBalanceRow(friend: friend)
                                    }
                                    .staggeredEntrance(index: index)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .animation(AppMotion.snappy, value: filteredFriends)
                    .animation(AppMotion.snappy, value: viewModel.errorMessage)
                }
            }
            .navigationTitle("Friends")
            .searchable(text: $searchText, prompt: "Search friends or aliases")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Add friend")
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
            .sheet(isPresented: $showAddFriend) {
                AddFriendSheet(viewModel: viewModel)
            }
        }
    }

    private var filterChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FriendBalanceFilter.allCases) { item in
                    let isSelected = filter == item
                    Button {
                        withAnimation(AppMotion.snappy) {
                            filter = item
                        }
                    } label: {
                        Text(item.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(isSelected ? .white : .primary)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(AppTheme.brandGradient)
                                        .matchedGeometryEffect(id: "friendFilterPill", in: filterNamespace)
                                } else {
                                    Capsule()
                                        .fill(Color(.secondarySystemGroupedBackground))
                                }
                            }
                    }
                    .buttonStyle(BoloPressButtonStyle(scale: 0.95))
                }
            }
            .padding(.horizontal, 2)
        }
        .sensoryFeedback(.selection, trigger: filter)
    }
}

private struct FriendBalanceRow: View {
    let friend: FriendRowItem

    var body: some View {
        HStack(spacing: 12) {
            UserAvatarBadge(
                name: friend.name,
                size: 44,
                ringColor: friend.netBalance == 0 ? nil : AppTheme.balanceColor(for: friend.netBalance)
            )

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
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.owedPositive)
                    Text(CurrencyFormatter.formatINR(friend.netBalance))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.owedPositive)
                        .contentTransition(.numericText())
                } else if friend.netBalance < 0 {
                    Text("you owe")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.owedNegative)
                    Text(CurrencyFormatter.formatINR(abs(friend.netBalance)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.owedNegative)
                        .contentTransition(.numericText())
                } else {
                    Text("settled up")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
