//
//  BoloSplitApp.swift
//  BoloSplit
//
//  App entry point: configures Firebase, Google Sign-In URL handling, and root environment.
//

import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct BoloSplitApp: App {
    @State private var environment: AppEnvironment

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        _environment = State(initialValue: AppEnvironment())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(environment)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
