//
//  MainTabView.swift
//  BoloSplit
//
//  Simple Splitwise-style 5-tab shell with an animated floating Bolo Mic action button.
//

import SwiftUI

enum AppTab: Hashable {
    case friends
    case groups
    case personal
    case activity
    case account
}

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: AppTab = .friends
    @State private var isFabPulsing = false

    private var voicePresentationBinding: Binding<Bool> {
        Binding(
            get: { environment.presentedVoiceViewModel != nil },
            set: { isPresented in
                if !isPresented {
                    environment.dismissVoiceOverlay()
                }
            }
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                FriendsTabView(viewModel: environment.friendsViewModel)
                    .contentMargins(.bottom, 84, for: .scrollContent)
                    .tabItem {
                        Label("Friends", systemImage: "person.2.fill")
                    }
                    .tag(AppTab.friends)

                GroupsTabView(viewModel: environment.groupsViewModel)
                    .contentMargins(.bottom, 84, for: .scrollContent)
                    .tabItem {
                        Label("Groups", systemImage: "person.3.fill")
                    }
                    .tag(AppTab.groups)

                SelfTabView(viewModel: environment.selfViewModel)
                    .contentMargins(.bottom, 84, for: .scrollContent)
                    .tabItem {
                        Label("Self", systemImage: "person.fill")
                    }
                    .tag(AppTab.personal)

                ActivityTabView(viewModel: environment.activityViewModel)
                    .contentMargins(.bottom, 84, for: .scrollContent)
                    .tabItem {
                        Label("Activity", systemImage: "list.bullet.rectangle")
                    }
                    .tag(AppTab.activity)

                AccountTabView(authViewModel: environment.authViewModel) {
                    environment.signOutAndReset()
                }
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
                .tag(AppTab.account)
            }
            .tint(AppTheme.brand)
            .sensoryFeedback(.selection, trigger: selectedTab)

            // Floating Siri-like "Bolo" Mic Trigger
            Button {
                environment.openVoiceOverlay()
            } label: {
                ZStack {
                    if !reduceMotion {
                        Capsule()
                            .stroke(AppTheme.brand.opacity(isFabPulsing ? 0.0 : 0.45), lineWidth: 2.5)
                            .scaleEffect(isFabPulsing ? 1.24 : 1.0)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.title3.weight(.semibold))
                            .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                        Text("Bolo")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(AppTheme.brandGradient, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                    )
                    .shadow(color: .teal.opacity(0.42), radius: 14, y: 6)
                }
                .fixedSize()
            }
            .buttonStyle(BoloPressButtonStyle(scale: 0.93, haptic: .medium))
            .padding(.trailing, 20)
            .padding(.bottom, 68)
            .accessibilityLabel("Speak expense")
            .onAppear {
                guard !reduceMotion, !isFabPulsing else { return }
                withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
                    isFabPulsing = true
                }
            }
        }
        .sheet(isPresented: voicePresentationBinding) {
            if let voiceViewModel = environment.presentedVoiceViewModel {
                SiriVoiceOverlayView(viewModel: voiceViewModel)
                    .presentationDetents([.height(520), .large])
                    .presentationCornerRadius(32)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
        .onAppear {
            environment.consumePendingDeepLinkIfNeeded()
        }
    }
}
