//
//  AuthService.swift
//  BoloSplit
//
//  Manages Firebase Google Sign-In sessions and optional DEBUG X-User-Email fallback.
//

import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import Observation
import UIKit

struct AuthUser: Equatable, Sendable {
    let uid: String
    let email: String
    let displayName: String
    let photoURL: URL?
    let isDevMode: Bool
}

enum AuthError: LocalizedError {
    case firebaseNotConfigured
    case missingPresentingViewController
    case missingGoogleIDToken
    case notAuthenticated
    case invalidEmail

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase is not configured. Ensure GoogleService-Info.plist is added to BoloSplit."
        case .missingPresentingViewController:
            return "Could not find an active window to present Google Sign-In."
        case .missingGoogleIDToken:
            return "Google Sign-In did not return an ID token."
        case .notAuthenticated:
            return "Please sign in to continue."
        case .invalidEmail:
            return "Please enter a valid email address."
        }
    }
}

protocol AuthServiceProtocol: AuthHeaderProviding {
    var currentUser: AuthUser? { get }
    var isAuthenticated: Bool { get }
    func restoreSession()
    func signInWithGoogle() async throws -> AuthUser
    func signInWithDevEmail(_ email: String) throws -> AuthUser
    func signOut() throws
}

@Observable
final class AuthService: AuthServiceProtocol {
    private static let devEmailDefaultsKey = "bolosplit.dev.userEmail"

    private(set) var currentUser: AuthUser?

    var isAuthenticated: Bool {
        currentUser != nil
    }

    init() {
        restoreSession()
    }

    func restoreSession() {
        if FirebaseApp.app() != nil, let fbUser = Auth.auth().currentUser {
            currentUser = Self.mapFirebaseUser(fbUser)
            return
        }
        #if DEBUG
        if let savedDevEmail = UserDefaults.standard.string(forKey: Self.devEmailDefaultsKey),
           !savedDevEmail.isEmpty {
            currentUser = Self.makeDevUser(email: savedDevEmail)
            return
        }
        #endif
        currentUser = nil
    }

    func signInWithGoogle() async throws -> AuthUser {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.firebaseNotConfigured
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presentingVC = topViewController() else {
            throw AuthError.missingPresentingViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingGoogleIDToken
        }

        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await Auth.auth().signIn(with: credential)

        UserDefaults.standard.removeObject(forKey: Self.devEmailDefaultsKey)
        let mapped = Self.mapFirebaseUser(authResult.user)
        currentUser = mapped
        return mapped
    }

    func signInWithDevEmail(_ email: String) throws -> AuthUser {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@"), trimmed.contains(".") else {
            throw AuthError.invalidEmail
        }
        UserDefaults.standard.set(trimmed, forKey: Self.devEmailDefaultsKey)
        let devUser = Self.makeDevUser(email: trimmed)
        currentUser = devUser
        return devUser
    }

    func signOut() throws {
        UserDefaults.standard.removeObject(forKey: Self.devEmailDefaultsKey)
        GIDSignIn.sharedInstance.signOut()
        if FirebaseApp.app() != nil, Auth.auth().currentUser != nil {
            try Auth.auth().signOut()
        }
        currentUser = nil
    }

    // MARK: - AuthHeaderProviding

    func authHeaders(forceRefresh: Bool) async throws -> [String: String] {
        if FirebaseApp.app() != nil, let fbUser = Auth.auth().currentUser {
            let token = try await fbUser.getIDToken(forcingRefresh: forceRefresh)
            return ["Authorization": "Bearer \(token)"]
        }

        if let user = currentUser, user.isDevMode {
            return ["X-User-Email": user.email]
        }

        throw AuthError.notAuthenticated
    }

    // MARK: - Helpers

    private static func mapFirebaseUser(_ user: User) -> AuthUser {
        let email = user.email ?? "user@bolosplit.app"
        let name = user.displayName ?? email.components(separatedBy: "@").first?.capitalized ?? "BoloSplit User"
        return AuthUser(
            uid: user.uid,
            email: email,
            displayName: name,
            photoURL: user.photoURL,
            isDevMode: false
        )
    }

    private static func makeDevUser(email: String) -> AuthUser {
        let name = email.components(separatedBy: "@").first?.capitalized ?? "Test User"
        return AuthUser(
            uid: "dev-\(email)",
            email: email,
            displayName: name,
            photoURL: nil,
            isDevMode: true
        )
    }

    private func topViewController() -> UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        guard let root = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
