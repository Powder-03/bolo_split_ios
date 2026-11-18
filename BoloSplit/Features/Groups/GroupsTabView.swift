//
//  GroupsTabView.swift
//  BoloSplit
//
//  Splitwise-style Groups list tab.
//

import SwiftUI

struct GroupsTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var viewModel: GroupsTabViewModel
    @State private var showCreateOrJoin = false

    var body: some View {
        NavigationStack {
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
                            subtitle: "Tap + to create a group or join one with a 6-character invite code."
                        )
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section("Your Groups") {
                        ForEach(viewModel.groups) { group in
                            NavigationLink {
                                GroupDetailView(
                                    viewModel: environment.makeGroupDetailViewModel(group: group)
                                )
                            } label: {
                                GroupRow(group: group)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Groups")
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
            .overlay {
                if viewModel.isLoading && viewModel.groups.isEmpty {
                    ProgressView("Loading groups...")
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

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.brand.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(AppTheme.brand)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.body.weight(.semibold))

                Text("Invite code: \(group.inviteCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
