//
//  FriendAliasesView.swift
//  BoloSplit
//
//  Manage custom per-user nicknames and spoken aliases for friends
//  so BoloSplit Voice and balances resolve without name conflicts.
//

import SwiftUI
import UIKit

struct FriendAliasesView: View {
    @Bindable var viewModel: FriendsTabViewModel
    var onAliasesUpdated: (() async -> Void)?

    @State private var searchText = ""
    @State private var selectedFriend: FriendRead?
    @State private var showAddFriend = false

    private var filteredFriends: [FriendRead] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.friends }
        return viewModel.friends.filter { friend in
            friend.friendName.localizedCaseInsensitiveContains(query)
                || (friend.nickname?.localizedCaseInsensitiveContains(query) ?? false)
                || friend.friendEmail.localizedCaseInsensitiveContains(query)
                || (friend.friendPhone?.localizedCaseInsensitiveContains(query) ?? false)
                || friend.aliases.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.friends.isEmpty {
                SkeletonLoadingView(showBannerCard: false, rowCount: 5)
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

                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "waveform.and.person.filled")
                                .font(.title3)
                                .foregroundStyle(AppTheme.brand)
                                .frame(width: 36, height: 36)
                                .background(
                                    AppTheme.brand.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Conflict-Free Custom Names")
                                    .font(.subheadline.weight(.semibold))
                                Text("Each nickname and spoken alias is unique to you. Use them in \"Bolo\" voice commands (e.g. \"Add 200 on Rishabh Office\") and across your balances.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if viewModel.friends.isEmpty && !viewModel.isLoading {
                        Section {
                            EmptyStateView(
                                systemImage: "person.2.fill",
                                title: "No friends yet",
                                subtitle: "Add a friend or join a group, then assign custom nicknames and spoken aliases here.",
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
                                subtitle: "Try searching by name, nickname, phone, email, or alias."
                            )
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        Section("Friends (\(filteredFriends.count))") {
                            ForEach(filteredFriends) { friend in
                                Button {
                                    selectedFriend = friend
                                } label: {
                                    FriendAliasRow(friend: friend)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Nicknames & Aliases")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search name, phone, email, or alias")
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
            if viewModel.friends.isEmpty {
                await viewModel.loadData()
            }
        }
        .sheet(item: $selectedFriend) { friend in
            EditFriendAliasSheet(
                friend: friend,
                viewModel: viewModel,
                onSaved: onAliasesUpdated
            )
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet(viewModel: viewModel)
        }
    }
}

private struct FriendAliasRow: View {
    let friend: FriendRead

    private var hasNickname: Bool {
        guard let nick = friend.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !nick.isEmpty
    }

    private var contactLabel: String {
        if let phone = friend.friendPhone, !phone.isEmpty {
            return phone
        }
        return friend.friendEmail
    }

    var body: some View {
        HStack(spacing: 12) {
            UserAvatarBadge(
                name: friend.displayName,
                size: 42,
                ringColor: hasNickname ? AppTheme.brand : nil
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(friend.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    if hasNickname {
                        Text("Nickname")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.brand)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.brand.opacity(0.12), in: Capsule())
                    }
                }

                Text(hasNickname && friend.displayName.lowercased() != friend.friendName.lowercased()
                     ? "\(friend.friendName) • \(contactLabel)"
                     : contactLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !friend.aliases.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(friend.aliases, id: \.self) { alias in
                                Text(alias)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                } else if !hasNickname {
                    Text("Tap to set nickname or spoken aliases")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct EditFriendAliasSheet: View {
    @Environment(\.dismiss) private var dismiss

    let friend: FriendRead
    @Bindable var viewModel: FriendsTabViewModel
    var onSaved: (() async -> Void)?

    @State private var nickname: String
    @State private var aliases: [String]
    @State private var newAliasText: String = ""
    @State private var localError: String?

    init(
        friend: FriendRead,
        viewModel: FriendsTabViewModel,
        onSaved: (() async -> Void)? = nil
    ) {
        self.friend = friend
        self.viewModel = viewModel
        self.onSaved = onSaved
        _nickname = State(initialValue: friend.nickname ?? "")
        _aliases = State(initialValue: friend.aliases)
    }

    private var pendingAliases: [String] {
        let extra = FriendsTabViewModel.parseAliases(from: newAliasText)
        return FriendsTabViewModel.normalizeAliases(aliases + extra)
    }

    private var conflictInfo: (friend: FriendRead, label: String)? {
        viewModel.conflictingFriend(
            forNickname: nickname,
            aliases: pendingAliases,
            excludingFriendId: friend.friendId
        )
    }

    private var hasAnyCustomization: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAliases.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if let localError {
                    Section {
                        Text(localError)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.owedNegative)
                    }
                }

                if let conflict = conflictInfo {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.owedNegative)
                            Text("\"\(conflict.label)\" is already assigned to \(conflict.friend.displayName). Choose a unique name to avoid voice & balance conflicts.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.owedNegative)
                        }
                    }
                }

                Section("Friend Account") {
                    HStack(spacing: 12) {
                        UserAvatarBadge(name: friend.friendName, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.friendName)
                                .font(.headline)
                            if let phone = friend.friendPhone, !phone.isEmpty {
                                Text(phone)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(friend.friendEmail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section {
                    HStack {
                        TextField("e.g. Rishabh Office, Flatmate", text: $nickname)
                            .textContentType(.nickname)
                        if !nickname.isEmpty {
                            Button {
                                nickname = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear nickname")
                        }
                    }
                } header: {
                    Text("Custom Nickname")
                } footer: {
                    Text("Shown on your Friends list, Balances, and Group rosters. Leave blank to display their account name.")
                }

                Section {
                    HStack(spacing: 8) {
                        TextField("Add alias (e.g. office bro, flatmate)", text: $newAliasText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit {
                                commitPendingAliases()
                            }

                        Button("Add") {
                            commitPendingAliases()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                        .disabled(FriendsTabViewModel.parseAliases(from: newAliasText).isEmpty)
                    }

                    if !aliases.isEmpty {
                        AliasChipWrapLayout(spacing: 8) {
                            ForEach(aliases, id: \.self) { alias in
                                HStack(spacing: 5) {
                                    Text(alias)
                                        .font(.caption.weight(.medium))
                                    Button {
                                        withAnimation(AppMotion.snappy) {
                                            aliases.removeAll { $0 == alias }
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove alias \(alias)")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.brand.opacity(0.12), in: Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Spoken Aliases (\(aliases.count))")
                } footer: {
                    Text("Add comma-separated or individual aliases so BoloSplit Voice matches this friend accurately (e.g. \"Add 200 on office bro\").")
                }

                if hasAnyCustomization {
                    Section {
                        Button("Clear Nickname & Aliases", role: .destructive) {
                            nickname = ""
                            aliases = []
                            newAliasText = ""
                            Task { await submit(clearAll: true) }
                        }
                        .disabled(viewModel.isSavingFriend)
                    }
                }
            }
            .navigationTitle("Edit Friend Alias")
            .navigationBarTitleDisplayMode(.inline)
            .animation(AppMotion.snappy, value: localError)
            .animation(AppMotion.snappy, value: aliases)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await submit(clearAll: false) }
                    }
                    .disabled(conflictInfo != nil || viewModel.isSavingFriend)
                }
            }
            .overlay {
                if viewModel.isSavingFriend {
                    ProgressView("Saving...")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func commitPendingAliases() {
        let parsed = FriendsTabViewModel.parseAliases(from: newAliasText)
        guard !parsed.isEmpty else { return }
        withAnimation(AppMotion.snappy) {
            aliases = FriendsTabViewModel.normalizeAliases(aliases + parsed)
            newAliasText = ""
        }
    }

    private func submit(clearAll: Bool) async {
        localError = nil
        let finalNickname: String? = clearAll ? nil : nickname
        let finalAliases: [String] = clearAll ? [] : pendingAliases

        let result = await viewModel.updateFriendAliases(
            friendId: friend.friendId,
            nickname: finalNickname,
            aliases: finalAliases
        )

        switch result {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await onSaved?()
            dismiss()
        case .failure(let error):
            localError = error.localizedDescription
        }
    }
}

private struct AliasChipWrapLayout: Layout {
    var spacing: CGFloat = 8

    nonisolated func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0 && currentX + size.width > maxWidth {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(
            width: maxWidth.isFinite ? maxWidth : currentX,
            height: currentY + rowHeight
        )
    }

    nonisolated func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX && currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
