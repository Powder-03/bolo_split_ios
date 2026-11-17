//
//  FriendDetailViewModel.swift
//  BoloSplit
//
//  ViewModel for 1-on-1 friend balance summary, bilateral timeline, and settlement undo.
//

import Foundation
import Observation

@Observable
final class FriendDetailViewModel {
    private let ledgerService: LedgerServiceProtocol
    private let onLedgerMutated: (() async -> Void)?

    let friend: FriendRowItem

    var feed: BilateralActivityFeed?
    var isLoading = false
    var errorMessage: String?

    init(
        friend: FriendRowItem,
        ledgerService: LedgerServiceProtocol,
        onLedgerMutated: (() async -> Void)? = nil
    ) {
        self.friend = friend
        self.ledgerService = ledgerService
        self.onLedgerMutated = onLedgerMutated
    }

    var netBalance: Decimal {
        feed?.netBalance ?? friend.netBalance
    }

    var timeline: [ActivityTimelineItem] {
        feed?.timeline ?? []
    }

    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        do {
            feed = try await ledgerService.fetchBilateralFeed(
                friendId: friend.id,
                limit: 50,
                offset: 0
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func undoSettlement(id: UUID) async {
        do {
            try await ledgerService.deleteSettlement(id: id)
            await loadFeed()
            await onLedgerMutated?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
