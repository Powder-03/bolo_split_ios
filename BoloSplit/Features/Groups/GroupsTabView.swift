//
//  GroupsTabView.swift
//  BoloSplit
//
//  Splitwise-style Groups list tab with search, skeleton loading, and tactile cards.
//

import SwiftUI

struct GroupsTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var viewModel: GroupsTabViewModel
    @State private var showCreateOrJoin = false
    @State private var searchText = ""

    private var filteredGroups: [GroupRead] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.groups }
        return viewModel.groups.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.inviteCode.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.groups.isEmpty {
                    SkeletonLoadingView(showBannerCard: false, rowCount: 5)
                } else {
                    List {
                        if let error = viewModel.errorMessage {
                            Section {
                                ErrorBanner(message: error) {
                                    Task { await viewModel.loadGroups() }
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

                        if viewModel.groups.isEmpty && !viewModel.isLoading {
                            Section {
                                EmptyStateView(
                                    systemImage: "person.3.fill",
                                    title: "No groups yet",
                                    subtitle: "Create a trip or flat group, or join one with a 6-character invite code.",
                                    actionTitle: "Create or Join Group"
                                ) {
                                    showCreateOrJoin = true
                                }
                            }
                            .listRowBackground(Color.clear)
                        } else if filteredGroups.isEmpty {
                            Section {
                                EmptyStateView(
                                    systemImage: "magnifyingglass",
                                    title: "No matching groups",
                                    subtitle: "Try a different group name or invite code."
                                )
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            Section("Your Groups (\(filteredGroups.count))") {
                                ForEach(Array(filteredGroups.enumerated()), id: \.element.id) { index, group in
                                    NavigationLink {
                                        GroupDetailView(
                                            viewModel: environment.makeGroupDetailViewModel(group: group)
                                        )
                                    } label: {
                                        GroupRow(group: group)
                                    }
                                    .staggeredEntrance(index: index)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .animation(AppMotion.snappy, value: filteredGroups)
                }
            }
            .navigationTitle("Groups")
            .searchable(text: $searchText, prompt: "Search groups or invite codes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateOrJoin = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Create or join group")
                }
            }
            .refreshable {
                await viewModel.loadGroups()
            }
            .task {
                await viewModel.loadIfNeeded()
            }
            .sheet(isPresented: $showCreateOrJoin) {
                CreateOrJoinGroupSheet(viewModel: viewModel)
            }
        }
    }
}

private struct GroupRow: View {
    let group: GroupRead

    private var tint: Color {
        AppTheme.avatarColor(for: group.name)
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(tint)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.body.weight(.semibold))

                Text("Code: \(group.inviteCode)")
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.10), in: Capsule())
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
