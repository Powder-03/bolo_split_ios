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
    var isSubmitting = false
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

    func createGroup(name: String) async -> Result<GroupRead, Error> {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(APIError.httpError(statusCode: 400, message: "Please enter a group name."))
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let group = try await ledgerService.createGroup(name: trimmed)
            await loadGroups()
            return .success(group)
        } catch {
            return .failure(error)
        }
    }

    func joinGroup(inviteCode: String) async -> Result<GroupRead, Error> {
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(APIError.httpError(statusCode: 400, message: "Please enter an invite code."))
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let group = try await ledgerService.joinGroup(inviteCode: trimmed)
            await loadGroups()
            return .success(group)
        } catch {
            return .failure(error)
        }
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
