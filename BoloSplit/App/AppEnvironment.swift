//
//  AppEnvironment.swift
//  BoloSplit
//
//  Central dependency container wiring Services and root ViewModels.
//

import Foundation
import Observation

@Observable
final class AppEnvironment {
    let authService: AuthService
    let apiClient: APIClient
    let authViewModel: AuthViewModel

    init() {
        let auth = AuthService()
        let client = APIClient(authProvider: auth)
        self.authService = auth
        self.apiClient = client
        self.authViewModel = AuthViewModel(authService: auth, apiClient: client)
    }
}
