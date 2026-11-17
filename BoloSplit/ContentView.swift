//
//  ContentView.swift
//  BoloSplit
//
//  Root view switching between LoginView and MainTabView.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Group {
            if environment.authViewModel.isAuthenticated {
                MainTabView()
            } else {
                LoginView(viewModel: environment.authViewModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: environment.authViewModel.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environment(AppEnvironment())
}
