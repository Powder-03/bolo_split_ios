//
//  GroupsTabViewModel.swift
//  BoloSplit
//
//  ViewModel for the Groups tab.
//

import Foundation
import Observation

@Observable
final class GroupsTabViewModel {
    private let ledgerService: LedgerServiceProtocol

    var groups: [GroupRead] = []
    var isLoading = false
    var errorMessage: String?
    private var hasLoadedOnce = false

    init(ledgerService: LedgerServiceProtocol) {
        self.ledgerService = ledgerService
    }

    func loadGroups() async {
        isLoading = true
        errorMessage = nil
        do {
            groups = try await ledgerService.fetchGroups()
            hasLoadedOnce = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadIfNeeded() async {
        if !hasLoadedOnce {
            await loadGroups()
        }
    }

    func clear() {
        groups = []
        errorMessage = nil
        hasLoadedOnce = false
    }
}
