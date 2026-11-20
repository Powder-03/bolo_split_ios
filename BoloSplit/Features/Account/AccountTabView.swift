//
//  AccountTabView.swift
//  BoloSplit
//
//  Splitwise-style Account tab: profile info, backend status, and sign out confirmation.
//

import SwiftUI

struct AccountTabView: View {
    @Bindable var authViewModel: AuthViewModel
    let onSignOut: () -> Void
    @State private var showSignOutConfirm = false

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
