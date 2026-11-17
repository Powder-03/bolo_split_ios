//
//  GroupsTabView.swift
//  BoloSplit
//
//  Splitwise-style Groups list tab.
//

import SwiftUI

struct GroupsTabView: View {
    @Bindable var viewModel: GroupsTabViewModel

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
                            subtitle: "Groups for trips, flatmates, and events will appear here."
                        )
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section("Your Groups") {
                        ForEach(viewModel.groups) { group in
                            GroupRow(group: group)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Groups")
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

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
