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
    func createFriend(_ payload: FriendCreate) async throws -> FriendRead
    func updateFriendAliases(friendId: UUID, payload: FriendUpdate) async throws -> FriendRead
    func fetchBilateralFeed(friendId: UUID, limit: Int, offset: Int) async throws -> BilateralActivityFeed
    func fetchGroups() async throws -> [GroupRead]
    func createGroup(name: String) async throws -> GroupRead
    func joinGroup(inviteCode: String) async throws -> GroupRead
    func fetchGroupDetail(groupId: UUID) async throws -> GroupDetailRead
    func addGroupMember(groupId: UUID, identifier: String, name: String?, role: String) async throws -> GroupMemberRead
    func fetchGroupFeed(groupId: UUID, limit: Int, offset: Int) async throws -> GroupActivityFeed
    func fetchExpenses(groupId: UUID?, scope: String?, limit: Int, offset: Int) async throws -> [ExpenseRead]
    func fetchExpenseDetail(id: UUID) async throws -> ExpenseRead
    func createExpense(_ payload: ExpenseCreate) async throws -> ExpenseRead
    func updateExpense(id: UUID, payload: ExpenseUpdate) async throws -> ExpenseRead
    func fetchSelfExpenses(limit: Int, offset: Int, category: String?, month: Int?, year: Int?) async throws -> SelfExpensesSummary
    func createSelfExpense(_ payload: SelfExpenseCreate) async throws -> SelfExpenseRead
    func updateSelfExpense(id: UUID, payload: SelfExpenseUpdate) async throws -> SelfExpenseRead
    func deleteSelfExpense(id: UUID) async throws
    func deleteExpense(id: UUID) async throws
    func fetchSettlements(friendId: UUID?, groupId: UUID?, limit: Int, offset: Int) async throws -> [SettlementRead]
    func createSettlement(_ payload: SettlementCreate) async throws -> SettlementRead
    func deleteSettlement(id: UUID) async throws
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

    func createFriend(_ payload: FriendCreate) async throws -> FriendRead {
        let endpoint = try Endpoint.post("/friends", body: payload)
        return try await apiClient.request(endpoint)
    }

    func updateFriendAliases(friendId: UUID, payload: FriendUpdate) async throws -> FriendRead {
        let endpoint = try Endpoint.patch("/friends/\(friendId.uuidString)", body: payload)
        return try await apiClient.request(endpoint)
    }

    func fetchBilateralFeed(friendId: UUID, limit: Int = 50, offset: Int = 0) async throws -> BilateralActivityFeed {
        let query = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        return try await apiClient.request(.get("/friends/\(friendId.uuidString)/expenses", queryItems: query))
    }

    func fetchGroups() async throws -> [GroupRead] {
        try await apiClient.request(.get("/groups"))
    }

    func createGroup(name: String) async throws -> GroupRead {
        let endpoint = try Endpoint.post("/groups", body: GroupCreate(name: name))
        return try await apiClient.request(endpoint)
    }

    func joinGroup(inviteCode: String) async throws -> GroupRead {
        let cleanCode = inviteCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let encodedCode = cleanCode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanCode
        return try await apiClient.request(.postEmpty("/groups/join/\(encodedCode)"))
    }

    func fetchGroupDetail(groupId: UUID) async throws -> GroupDetailRead {
        try await apiClient.request(.get("/groups/\(groupId.uuidString)"))
    }

    func addGroupMember(
        groupId: UUID,
        identifier: String,
        name: String? = nil,
        role: String = "member"
    ) async throws -> GroupMemberRead {
        let payload = GroupMemberAdd(identifier: identifier, name: name, role: role)
        let endpoint = try Endpoint.post("/groups/\(groupId.uuidString)/members", body: payload)
        return try await apiClient.request(endpoint)
    }

    func fetchGroupFeed(groupId: UUID, limit: Int = 50, offset: Int = 0) async throws -> GroupActivityFeed {
        let query = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        return try await apiClient.request(.get("/groups/\(groupId.uuidString)/expenses", queryItems: query))
    }

    func fetchExpenses(groupId: UUID? = nil, scope: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> [ExpenseRead] {
        var query = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let groupId {
            query.append(URLQueryItem(name: "group_id", value: groupId.uuidString))
        }
        if let scope {
            query.append(URLQueryItem(name: "scope", value: scope))
        }
        return try await apiClient.request(.get("/expenses", queryItems: query))
    }

    func fetchExpenseDetail(id: UUID) async throws -> ExpenseRead {
        try await apiClient.request(.get("/expenses/\(id.uuidString)"))
    }

    func createExpense(_ payload: ExpenseCreate) async throws -> ExpenseRead {
        let endpoint = try Endpoint.post("/expenses", body: payload)
        return try await apiClient.request(endpoint)
    }

    func updateExpense(id: UUID, payload: ExpenseUpdate) async throws -> ExpenseRead {
        let endpoint = try Endpoint.patch("/expenses/\(id.uuidString)", body: payload)
        return try await apiClient.request(endpoint)
    }

    func fetchSelfExpenses(
        limit: Int = 50,
        offset: Int = 0,
        category: String? = nil,
        month: Int? = nil,
        year: Int? = nil
    ) async throws -> SelfExpensesSummary {
        var query = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let category {
            query.append(URLQueryItem(name: "category", value: category))
        }
        if let month {
            query.append(URLQueryItem(name: "month", value: String(month)))
        }
        if let year {
            query.append(URLQueryItem(name: "year", value: String(year)))
        }
        return try await apiClient.request(.get("/expenses/self", queryItems: query))
    }

    func createSelfExpense(_ payload: SelfExpenseCreate) async throws -> SelfExpenseRead {
        let endpoint = try Endpoint.post("/expenses/self", body: payload)
        return try await apiClient.request(endpoint)
    }

    func updateSelfExpense(id: UUID, payload: SelfExpenseUpdate) async throws -> SelfExpenseRead {
        let endpoint = try Endpoint.patch("/expenses/self/\(id.uuidString)", body: payload)
        return try await apiClient.request(endpoint)
    }

    func deleteSelfExpense(id: UUID) async throws {
        try await apiClient.requestVoid(.delete("/expenses/self/\(id.uuidString)"))
    }

    func deleteExpense(id: UUID) async throws {
        try await apiClient.requestVoid(.delete("/expenses/\(id.uuidString)"))
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

    func createSettlement(_ payload: SettlementCreate) async throws -> SettlementRead {
        let endpoint = try Endpoint.post("/settlements", body: payload)
        return try await apiClient.request(endpoint)
    }

    func deleteSettlement(id: UUID) async throws {
        try await apiClient.requestVoid(.delete("/settlements/\(id.uuidString)"))
    }
}
