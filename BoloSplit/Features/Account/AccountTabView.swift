//
//  AccountTabView.swift
//  BoloSplit
//
//  Splitwise-style Account tab: profile info, backend status, and sign out.
//

import SwiftUI

struct AccountTabView: View {
    @Bindable var authViewModel: AuthViewModel
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if let user = authViewModel.currentUser {
                    Section {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(AppTheme.brand.opacity(0.18))
                                .frame(width: 56, height: 56)
                                .overlay {
                                    Text(String(user.displayName.prefix(1)).uppercased())
                                        .font(.title2.bold())
                                        .foregroundStyle(AppTheme.brand)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.headline)

                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text(user.isDevMode ? "Dev X-User-Email" : "Google • Firebase Auth")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.brand.opacity(0.14), in: Capsule())
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section("Backend") {
                    LabeledContent("Server") {
                        Text(AppConfig.baseURL.host ?? AppConfig.baseURL.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Currency") {
                        Text("INR (₹)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        onSignOut()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Account")
        }
    }
}
