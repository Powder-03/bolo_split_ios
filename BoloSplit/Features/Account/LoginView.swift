//
//  LoginView.swift
//  BoloSplit
//
//  Splitwise-inspired clean login screen with animated hero orb, Google Sign-In & DEBUG email fallback.
//

import GoogleSignInSwift
import SwiftUI

struct LoginView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: AuthViewModel
    @State private var showDevLogin = false
    @State private var isBreathing = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Brand Header
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.brand.opacity(0.14))
                        .frame(width: 124, height: 124)
                        .scaleEffect(isBreathing ? 1.12 : 0.94)
                        .opacity(isBreathing ? 0.45 : 0.85)

                    Circle()
                        .strokeBorder(AppTheme.brand.opacity(0.28), lineWidth: 1.5)
                        .frame(width: 104, height: 104)
                        .scaleEffect(isBreathing ? 1.06 : 0.97)

                    Circle()
                        .fill(AppTheme.brandGradient)
                        .frame(width: 88, height: 88)
                        .shadow(color: .teal.opacity(0.38), radius: 16, y: 6)

                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse.byLayer, options: .repeating, isActive: !reduceMotion)
                }
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)

                Text("BoloSplit")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Text("Just speak your expenses.\nSimple splits, zero friction.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
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
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Google Sign-In Button
            VStack(spacing: 14) {
                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    HStack(spacing: 12) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                        }
                        Text(viewModel.isLoading ? "Signing in..." : "Continue with Google")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: AppTheme.brand.opacity(0.32), radius: 12, y: 5)
                }
                .buttonStyle(BoloPressButtonStyle(haptic: .medium))
                .disabled(viewModel.isLoading)

                #if DEBUG
                DisclosureGroup("Developer Quick Sign-In (X-User-Email)", isExpanded: $showDevLogin) {
                    VStack(spacing: 10) {
                        TextField("testuser@example.com", text: $viewModel.devEmailInput)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button("Sign In with Dev Email") {
                            Task { await viewModel.signInWithDevEmail() }
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.brand)
                        .frame(maxWidth: .infinity)
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.top, 8)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                #endif
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

            Text("Connected to \(AppConfig.baseURL.host ?? "Render")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .animation(AppMotion.snappy, value: viewModel.errorMessage)
        .animation(AppMotion.snappy, value: showDevLogin)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(AppMotion.gentle) {
                    appeared = true
                }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
        }
    }
}
