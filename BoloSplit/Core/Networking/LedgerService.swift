//
//  LedgerService.swift
//  BoloSplit
//
//  Service layer for Balances, Friends, Groups, Expenses, and Settlements.
//

import Foundation

protocol LedgerServiceProtocol {
    func fetchBalances(groupId: UUID?) async throws -> BalanceSummary
    func fetchFriends() async throws -> [FriendRead]
    func fetchGroups() async throws -> [GroupRead]
    func fetchExpenses(groupId: UUID?, limit: Int, offset: Int) async throws -> [ExpenseRead]
    func fetchSettlements(friendId: UUID?, groupId: UUID?, limit: Int, offset: Int) async throws -> [SettlementRead]
}

final class LedgerService: LedgerServiceProtocol {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func fetchBalances(groupId: UUID? = nil) async throws -> BalanceSummary {
        var query: [URLQueryItem] = []
        if let groupId {
            query.append(URLQueryItem(name: "group_id", value: groupId.uuidString))
        }
        return try await apiClient.request(.get("/balances", queryItems: query))
    }

    func fetchFriends() async throws -> [FriendRead] {
        try await apiClient.request(.get("/friends"))
    }

    func fetchGroups() async throws -> [GroupRead] {
        try await apiClient.request(.get("/groups"))
    }

    func fetchExpenses(groupId: UUID? = nil, limit: Int = 50, offset: Int = 0) async throws -> [ExpenseRead] {
        var query = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let groupId {
            query.append(URLQueryItem(name: "group_id", value: groupId.uuidString))
        }
        return try await apiClient.request(.get("/expenses", queryItems: query))
    }

    func fetchSettlements(friendId: UUID? = nil, groupId: UUID? = nil, limit: Int = 50, offset: Int = 0) async throws -> [SettlementRead] {
        var query = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let friendId {
            query.append(URLQueryItem(name: "friend_id", value: friendId.uuidString))
        }
        if let groupId {
            query.append(URLQueryItem(name: "group_id", value: groupId.uuidString))
        }
        return try await apiClient.request(.get("/settlements", queryItems: query))
    }
}
