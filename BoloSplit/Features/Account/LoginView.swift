//
//  LoginView.swift
//  BoloSplit
//
//  Splitwise-inspired clean login screen supporting Google Sign-In & DEBUG email fallback.
//

import GoogleSignInSwift
import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var showDevLogin = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Brand Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.teal, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .shadow(color: .teal.opacity(0.35), radius: 14, y: 6)

                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("BoloSplit")
                    .font(.largeTitle.bold())

                Text("Just speak your expenses.\nSimple splits, zero friction.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Error banner
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }

            // Google Sign-In Button
            VStack(spacing: 14) {
                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    HStack(spacing: 12) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.primary)
                        } else {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                        }
                        Text(viewModel.isLoading ? "Signing in..." : "Continue with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(viewModel.isLoading)

                #if DEBUG
                DisclosureGroup("Developer Quick Sign-In (X-User-Email)", isExpanded: $showDevLogin) {
                    VStack(spacing: 10) {
                        TextField("testuser@example.com", text: $viewModel.devEmailInput)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                        Button("Sign In with Dev Email") {
                            Task { await viewModel.signInWithDevEmail() }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.top, 8)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                #endif
            }

            Text("Connected to \(AppConfig.baseURL.host ?? "Render")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
    }
}
