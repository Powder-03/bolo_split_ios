//
//  GroupDetailViewModel.swift
//  BoloSplit
//
//  ViewModel loading group roster, group balances, timeline, and member management.
//

import Foundation
import Observation

@Observable
final class GroupDetailViewModel {
    private let ledgerService: LedgerServiceProtocol
    private let onLedgerMutated: (() async -> Void)?

    let group: GroupRead

    var detail: GroupDetailRead?
    var feed: GroupActivityFeed?
    var groupBalances: BalanceSummary?
    var isLoading = false
    var isAddingMember = false
    var errorMessage: String?

    init(
        group: GroupRead,
        ledgerService: LedgerServiceProtocol,
        onLedgerMutated: (() async -> Void)? = nil
    ) {
        self.group = group
        self.ledgerService = ledgerService
        self.onLedgerMutated = onLedgerMutated
    }

    var members: [GroupMemberRead] {
        detail?.members ?? []
    }

    var timeline: [ActivityTimelineItem] {
        feed?.timeline ?? []
    }

    var totalSpending: Decimal {
        detail?.totalSpending ?? feed?.totalSpending ?? 0
    }

    var inviteCode: String {
        detail?.inviteCode ?? group.inviteCode
    }

    func loadGroupData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let detailTask = ledgerService.fetchGroupDetail(groupId: group.id)
            async let feedTask = ledgerService.fetchGroupFeed(groupId: group.id, limit: 50, offset: 0)
            async let balancesTask = ledgerService.fetchBalances(groupId: group.id)

            let (loadedDetail, loadedFeed, loadedBalances) = try await (detailTask, feedTask, balancesTask)
            detail = loadedDetail
            feed = loadedFeed
            groupBalances = loadedBalances
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addMember(identifier: String, name: String?) async -> Result<GroupMemberRead, Error> {
        let cleanId = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else {
            return .failure(APIError.httpError(statusCode: 400, message: "Please enter an email or phone number."))
        }

        isAddingMember = true
        defer { isAddingMember = false }

        do {
            let member = try await ledgerService.addGroupMember(
                groupId: group.id,
                identifier: cleanId,
                name: (cleanName?.isEmpty == false) ? cleanName : nil,
                role: "member"
            )
            await loadGroupData()
            await onLedgerMutated?()
            return .success(member)
        } catch {
            return .failure(error)
        }
    }

    func deleteExpense(id: UUID) async {
        do {
            try await ledgerService.deleteExpense(id: id)
            await loadGroupData()
            await onLedgerMutated?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undoSettlement(id: UUID) async {
        do {
            try await ledgerService.deleteSettlement(id: id)
            await loadGroupData()
            await onLedgerMutated?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
