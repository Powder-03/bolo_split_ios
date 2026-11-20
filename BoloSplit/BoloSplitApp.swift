//
//  BoloSplitApp.swift
//  BoloSplit
//
//  App entry point: configures Firebase, Google Sign-In URL handling, deep links, and root environment.
//

import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct BoloSplitApp: App {
    @State private var environment: AppEnvironment

    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
        } else {
            print("[BoloSplit] Warning: GoogleService-Info.plist not found in app bundle. Firebase not initialized. Developer Quick Sign-In is enabled for testing.")
        }
        _environment = State(initialValue: AppEnvironment())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(environment)
                .onOpenURL { url in
                    if url.scheme?.lowercased() == "bolosplit" {
                        environment.handleDeepLink(url)
                    } else {
                        GIDSignIn.sharedInstance.handle(url)
                    }
                }
        }
    }
}
