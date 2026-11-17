//
//  MainTabView.swift
//  BoloSplit
//
//  Simple Splitwise-style 4-tab shell with a floating Bolo Mic action button.
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
    @State private var selectedTab: AppTab = .friends

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
                    .tabItem {
                        Label("Friends", systemImage: "person.2.fill")
                    }
                    .tag(AppTab.friends)

                GroupsTabView(viewModel: environment.groupsViewModel)
                    .tabItem {
                        Label("Groups", systemImage: "person.3.fill")
                    }
                    .tag(AppTab.groups)

                SelfTabView(viewModel: environment.selfViewModel)
                    .tabItem {
                        Label("Self", systemImage: "person.fill")
                    }
                    .tag(AppTab.personal)

                ActivityTabView(viewModel: environment.activityViewModel)
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

            // Floating Siri-like "Bolo" Mic Trigger
            Button {
                environment.openVoiceOverlay()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.title3.weight(.semibold))
                    Text("Bolo")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.teal, Color(red: 0.08, green: 0.68, blue: 0.56)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .shadow(color: .teal.opacity(0.4), radius: 12, y: 6)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 68)
            .accessibilityLabel("Speak expense")
        }
        .sheet(isPresented: voicePresentationBinding) {
            if let voiceViewModel = environment.presentedVoiceViewModel {
                SiriVoiceOverlayView(viewModel: voiceViewModel)
                    .presentationDetents([.height(500), .large])
                    .presentationCornerRadius(32)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }
}
