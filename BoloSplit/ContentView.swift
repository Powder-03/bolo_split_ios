//
//  ContentView.swift
//  BoloSplit
//
//  Root view switching between LoginView and MainTabView with smooth transitions.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        ZStack {
            if environment.authViewModel.isAuthenticated {
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                        removal: .opacity
                    ))
            } else {
                LoginView(viewModel: environment.authViewModel)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .scale(scale: 1.03))
                    ))
            }
        }
        .animation(AppMotion.gentle, value: environment.authViewModel.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environment(AppEnvironment())
}
