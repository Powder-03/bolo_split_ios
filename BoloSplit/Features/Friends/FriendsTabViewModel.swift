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

    var displayName: String {
        if let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nickname.isEmpty {
            return nickname
        }
        return name
    }
}

@Observable
final class FriendsTabViewModel {
    private let ledgerService: LedgerServiceProtocol

    var balanceSummary: BalanceSummary?
    var friends: [FriendRead] = []
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

            let (summary, loadedFriends) = try await (balancesTask, friendsTask)
            balanceSummary = summary
            friends = loadedFriends.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            friendRows = Self.merge(summary: summary, friends: loadedFriends)
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
        let parsedAliases = Self.parseAliases(from: aliasesText)

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

    func updateFriendAliases(
        friendId: UUID,
        nickname: String?,
        aliases: [String]
    ) async -> Result<FriendRead, Error> {
        let trimmedNickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNickname = (trimmedNickname?.isEmpty == false) ? trimmedNickname : nil
        let cleanAliases = Self.normalizeAliases(aliases)

        let payload = FriendUpdate(
            nickname: cleanNickname,
            aliases: cleanAliases,
            includeNickname: true
        )

        isSavingFriend = true
        defer { isSavingFriend = false }

        do {
            let updated = try await ledgerService.updateFriendAliases(friendId: friendId, payload: payload)
            await loadData()
            return .success(updated)
        } catch {
            return .failure(error)
        }
    }

    func conflictingFriend(
        forNickname nickname: String?,
        aliases: [String],
        excludingFriendId: UUID?
    ) -> (friend: FriendRead, label: String)? {
        var candidateLabels = Set(Self.normalizeAliases(aliases))
        if let cleanNick = nickname?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !cleanNick.isEmpty {
            candidateLabels.insert(cleanNick)
        }
        guard !candidateLabels.isEmpty else { return nil }

        for other in friends where other.friendId != excludingFriendId {
            var otherLabels = Set(Self.normalizeAliases(other.aliases))
            if let otherNick = other.nickname?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               !otherNick.isEmpty {
                otherLabels.insert(otherNick)
            }
            let overlap = candidateLabels.intersection(otherLabels).sorted()
            if let firstConflict = overlap.first {
                return (other, firstConflict)
            }
        }
        return nil
    }

    static func parseAliases(from text: String) -> [String] {
        normalizeAliases(text.split(separator: ",").map(String.init))
    }

    static func normalizeAliases(_ rawAliases: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in rawAliases {
            let norm = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !norm.isEmpty && !seen.contains(norm) {
                seen.insert(norm)
                result.append(norm)
            }
        }
        return result
    }

    func clear() {
        balanceSummary = nil
        friends = []
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
            let matchedBal = balanceMap[friend.friendId]
            let net = matchedBal?.netBalance ?? 0
            rowsById[friend.friendId] = FriendRowItem(
                id: friend.friendId,
                name: friend.friendName,
                nickname: friend.nickname ?? matchedBal?.nickname,
                netBalance: net,
                aliases: friend.aliases
            )
        }

        // Include anyone with a non-zero balance even if not yet in Friendship table
        for bal in summary.balances where rowsById[bal.userId] == nil {
            rowsById[bal.userId] = FriendRowItem(
                id: bal.userId,
                name: bal.userName,
                nickname: bal.nickname,
                netBalance: bal.netBalance,
                aliases: []
            )
        }

        // Non-zero balances first (Splitwise style), then alphabetical by displayName
        return rowsById.values.sorted { lhs, rhs in
            let lhsZero = lhs.netBalance == 0
            let rhsZero = rhs.netBalance == 0
            if lhsZero != rhsZero {
                return !lhsZero
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}
