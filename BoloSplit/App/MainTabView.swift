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
    case activity
    case account
}

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selectedTab: AppTab = .friends
    @State private var showVoicePlaceholder = false

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

            // Floating Siri-like "Bolo" Mic Trigger (wired to SiriVoiceOverlayView in Phase 3)
            Button {
                showVoicePlaceholder = true
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
        .sheet(isPresented: $showVoicePlaceholder) {
            VoiceComingSoonSheet()
                .presentationDetents([.height(260)])
                .presentationBackground(.ultraThinMaterial)
        }
    }
}

private struct VoiceComingSoonSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(LinearGradient(colors: [.teal, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 68, height: 68)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.title)
                        .foregroundStyle(.white)
                }

            Text("Siri-Like Voice Overlay")
                .font(.title3.bold())

            Text("Ready for Phase 3: tap Bolo, speak your expense in Hinglish/English, tap End, and it's added instantly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brand)
        }
        .padding()
    }
}
