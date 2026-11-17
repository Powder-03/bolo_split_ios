//
//  AppEnvironment.swift
//  BoloSplit
//
//  Central dependency container wiring Services and ViewModels.
//

import Foundation
import Observation

@Observable
final class AppEnvironment {
    let authService: AuthService
    let apiClient: APIClient
    let ledgerService: LedgerService

    let authViewModel: AuthViewModel
    let friendsViewModel: FriendsTabViewModel
    let groupsViewModel: GroupsTabViewModel
    let activityViewModel: ActivityTabViewModel

    init() {
        let auth = AuthService()
        let client = APIClient(authProvider: auth)
        let ledger = LedgerService(apiClient: client)

        self.authService = auth
        self.apiClient = client
        self.ledgerService = ledger

        self.authViewModel = AuthViewModel(authService: auth, apiClient: client)
        self.friendsViewModel = FriendsTabViewModel(ledgerService: ledger)
        self.groupsViewModel = GroupsTabViewModel(ledgerService: ledger)
        self.activityViewModel = ActivityTabViewModel(ledgerService: ledger)
    }

    func refreshAllFeeds() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.friendsViewModel.loadData() }
            group.addTask { await self.groupsViewModel.loadGroups() }
            group.addTask { await self.activityViewModel.loadActivity() }
        }
    }

    func signOutAndReset() {
        authViewModel.signOut()
        friendsViewModel.clear()
        groupsViewModel.clear()
        activityViewModel.clear()
    }
}
