//
//  AccountTabView.swift
//  BoloSplit
//
//  Splitwise-style Account tab: profile info, backend status, and sign out confirmation.
//

import SwiftUI

struct AccountTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var authViewModel: AuthViewModel
    let onSignOut: () -> Void
    @State private var showSignOutConfirm = false

    private var customizedAliasCount: Int {
        environment.friendsViewModel.friends.filter { friend in
            let hasNick = !(friend.nickname?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            return hasNick || !friend.aliases.isEmpty
        }.count
    }

    var body: some View {
        NavigationStack {
            List {
                if let user = authViewModel.currentUser {
                    Section {
                        HStack(spacing: 14) {
                            UserAvatarBadge(
                                name: user.displayName,
                                size: 58,
                                ringColor: AppTheme.brand
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.headline)

                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text(user.isDevMode ? "Dev X-User-Email" : "Google • Firebase Auth")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.brand)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.brand.opacity(0.14), in: Capsule())
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section {
                    NavigationLink {
                        FriendAliasesView(viewModel: environment.friendsViewModel) {
                            await environment.refreshAllFeeds()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.text.rectangle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.brand)
                                .frame(width: 34, height: 34)
                                .background(
                                    AppTheme.brand.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Friend Nicknames & Aliases")
                                    .font(.body.weight(.medium))

                                Text(customizedAliasCount > 0
                                     ? "\(customizedAliasCount) customized • Manage voice & balance names"
                                     : "Custom names for voice & balances without conflicts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                } header: {
                    Text("Voice & Friends")
                } footer: {
                    Text("Give friends unique nicknames and spoken aliases (like \"Rishabh Office\" or \"flatmate\") so BoloSplit resolves balances and voice commands without name collisions.")
                }

                Section {
                    LabeledContent("Currency") {
                        Text("INR (₹)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showSignOutConfirm = true
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Account")
            .confirmationDialog(
                "Sign out of BoloSplit?",
                isPresented: $showSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    onSignOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can sign back in anytime with Google.")
            }
        }
    }
}
