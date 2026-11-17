//
//  FriendsTabViewModel.swift
//  BoloSplit
//
//  ViewModel for Splitwise-style Friends tab (overall balances + per-friend rows).
//

import Foundation
import Observation

struct FriendRowItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let nickname: String?
    let netBalance: Decimal
    let aliases: [String]
}

@Observable
final class FriendsTabViewModel {
    private let ledgerService: LedgerServiceProtocol

    var balanceSummary: BalanceSummary?
    var friendRows: [FriendRowItem] = []
    var isLoading = false
    var isSavingFriend = false
    var errorMessage: String?

    init(ledgerService: LedgerServiceProtocol) {
        self.ledgerService = ledgerService
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let balancesTask = ledgerService.fetchBalances(groupId: nil)
            async let friendsTask = ledgerService.fetchFriends()

            let (summary, friends) = try await (balancesTask, friendsTask)
            balanceSummary = summary
            friendRows = Self.merge(summary: summary, friends: friends)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addFriend(
        name: String,
        email: String?,
        phone: String?,
        nickname: String?,
        aliasesText: String
    ) async -> Result<FriendRead, Error> {
        let cleanEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = phone?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)

        let parsedAliases = aliasesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        let payload = FriendCreate(
            friendEmail: (cleanEmail?.isEmpty == false) ? cleanEmail : nil,
            friendPhone: (cleanPhone?.isEmpty == false) ? cleanPhone : nil,
            friendName: cleanName.isEmpty ? nil : cleanName,
            nickname: (cleanNickname?.isEmpty == false) ? cleanNickname : nil,
            aliases: parsedAliases
        )

        isSavingFriend = true
        defer { isSavingFriend = false }

        do {
            let created = try await ledgerService.createFriend(payload)
            await loadData()
            return .success(created)
        } catch {
            return .failure(error)
        }
    }

    func clear() {
        balanceSummary = nil
        friendRows = []
        errorMessage = nil
    }

    private static func merge(summary: BalanceSummary, friends: [FriendRead]) -> [FriendRowItem] {
        var balanceMap: [UUID: UserBalance] = [:]
        for bal in summary.balances {
            balanceMap[bal.userId] = bal
        }

        var rowsById: [UUID: FriendRowItem] = [:]

        for friend in friends {
            let net = balanceMap[friend.friendId]?.netBalance ?? 0
            rowsById[friend.friendId] = FriendRowItem(
                id: friend.friendId,
                name: friend.friendName,
                nickname: friend.nickname,
                netBalance: net,
                aliases: friend.aliases
            )
        }

        // Include anyone with a non-zero balance even if not yet in Friendship table
        for bal in summary.balances where rowsById[bal.userId] == nil {
            rowsById[bal.userId] = FriendRowItem(
                id: bal.userId,
                name: bal.userName,
                nickname: nil,
                netBalance: bal.netBalance,
                aliases: []
            )
        }

        // Non-zero balances first (Splitwise style), then alphabetical
        return rowsById.values.sorted { lhs, rhs in
            let lhsZero = lhs.netBalance == 0
            let rhsZero = rhs.netBalance == 0
            if lhsZero != rhsZero {
                return !lhsZero
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
