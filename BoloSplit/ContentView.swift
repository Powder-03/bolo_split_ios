//
//  ContentView.swift
//  BoloSplit
//
//  Root view switching between LoginView and authenticated app shell.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Group {
            if environment.authViewModel.isAuthenticated {
                PhaseOneVerifiedView(viewModel: environment.authViewModel)
            } else {
                LoginView(viewModel: environment.authViewModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: environment.authViewModel.isAuthenticated)
    }
}

/// Temporary Phase 1 shell proving authenticated GET /balances works with Firebase JWT or Dev Email.
private struct PhaseOneVerifiedView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let user = viewModel.currentUser {
                    VStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 52))
                            .foregroundStyle(.teal)

                        Text("Welcome, \(user.displayName)")
                            .font(.title2.bold())

                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(user.isDevMode ? "Auth: Dev X-User-Email" : "Auth: Firebase Google JWT")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.teal.opacity(0.14), in: Capsule())
                    }
                }

                VStack(spacing: 12) {
                    if viewModel.isVerifyingBackend {
                        ProgressView()
                        Text("Verifying GET /balances...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let summary = viewModel.balanceSummary {
                        Text("Authenticated API Connected")
                            .font(.headline)
                            .foregroundStyle(.green)

                        HStack(spacing: 20) {
                            VStack {
                                Text("You are owed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(CurrencyFormatter.formatINR(summary.totalOwedToYou))
                                    .font(.headline)
                                    .foregroundStyle(.green)
                            }
                            Divider().frame(height: 32)
                            VStack {
                                Text("You owe")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(CurrencyFormatter.formatINR(summary.totalYouOwe))
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.top, 4)
                    } else if let err = viewModel.verificationError {
                        Text("Auth Check Failed")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                Button("Re-test GET /balances") {
                    Task { await viewModel.verifyAuthenticatedSession() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(viewModel.isVerifyingBackend)

                Spacer()
            }
            .padding(24)
            .navigationTitle("BoloSplit")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out", role: .destructive) {
                        viewModel.signOut()
                    }
                }
            }
            .task {
                if viewModel.balanceSummary == nil {
                    await viewModel.verifyAuthenticatedSession()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppEnvironment())
}
