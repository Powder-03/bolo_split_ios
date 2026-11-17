//
//  AuthViewModel.swift
//  BoloSplit
//
//  ViewModel handling Google Sign-In, Dev Email Sign-In, and session state.
//

import Foundation
import Observation

@Observable
final class AuthViewModel {
    private let authService: AuthServiceProtocol
    private let apiClient: APIClientProtocol

    var devEmailInput = "testuser@example.com"
    var isLoading = false
    var errorMessage: String?

    // Phase 1 authenticated API verification state
    var balanceSummary: BalanceSummary?
    var isVerifyingBackend = false
    var verificationError: String?

    var currentUser: AuthUser? {
        authService.currentUser
    }

    var isAuthenticated: Bool {
        authService.isAuthenticated
    }

    init(authService: AuthServiceProtocol, apiClient: APIClientProtocol) {
        self.authService = authService
        self.apiClient = apiClient
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await authService.signInWithGoogle()
            await verifyAuthenticatedSession()
        } catch {
            // Ignore user-cancelled Google Sign-In sheet
            let nsError = error as NSError
            if !(nsError.domain == "com.google.GIDSignIn" && nsError.code == -5) {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    func signInWithDevEmail() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try authService.signInWithDevEmail(devEmailInput)
            await verifyAuthenticatedSession()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        do {
            try authService.signOut()
            balanceSummary = nil
            verificationError = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyAuthenticatedSession() async {
        isVerifyingBackend = true
        verificationError = nil
        do {
            let summary: BalanceSummary = try await apiClient.request(.get("/balances"))
            balanceSummary = summary
        } catch {
            verificationError = error.localizedDescription
        }
        isVerifyingBackend = false
    }
}
