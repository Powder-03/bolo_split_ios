//
//  MockLedgerService.swift
//  BoloSplitTests
//
//  Mock implementation of LedgerServiceProtocol for isolated unit testing.
//

import Foundation
@testable import BoloSplit

final class MockLedgerService: LedgerServiceProtocol {
    var mockBalances: BalanceSummary = BalanceSummary(
        totalOwedToYou: 500,
        totalYouOwe: 250,
        netTotal: 250,
        balances: []
    )
    var mockFriends: [FriendRead] = []
    var mockGroups: [GroupRead] = []
    var mockExpenses: [ExpenseRead] = []
    var mockSelfExpenses: SelfExpensesSummary = SelfExpensesSummary(
        totalSpending: 0,
        thisMonthSpending: 0,
        totalCount: 0,
        currency: "INR",
        categories: [],
        expenses: []
    )
    var mockSettlement: SettlementRead?

    var shouldThrowError: Error?
    var didCallFetchBalances = false
    var didCallFetchFriends = false
    var didCallCreateSettlement = false
    var lastSettlementPayload: SettlementCreate?

    func fetchBalances(groupId: UUID?) async throws -> BalanceSummary {
        if let shouldThrowError { throw shouldThrowError }
        didCallFetchBalances = true
        return mockBalances
    }

    func fetchFriends() async throws -> [FriendRead] {
        if let shouldThrowError { throw shouldThrowError }
        didCallFetchFriends = true
        return mockFriends
    }

    func createFriend(_ payload: FriendCreate) async throws -> FriendRead {
        if let shouldThrowError { throw shouldThrowError }
        guard (payload.friendEmail != nil && !payload.friendEmail!.isEmpty) ||
              (payload.friendPhone != nil && !payload.friendPhone!.isEmpty) else {
            throw APIError.httpError(statusCode: 422, message: "Either email or phone number is required.")
        }
        let friend = FriendRead(
            id: UUID(),
            userId: UUID(),
            friendId: UUID(),
            friendName: payload.friendName ?? payload.nickname ?? "Friend",
            friendEmail: payload.friendEmail ?? "friend@example.com",
            friendPhone: payload.friendPhone,
            nickname: payload.nickname,
            aliases: payload.aliases,
            createdAt: Date()
        )
        mockFriends.append(friend)
        return friend
    }

    func fetchBilateralFeed(friendId: UUID, limit: Int, offset: Int) async throws -> BilateralActivityFeed {
        if let shouldThrowError { throw shouldThrowError }
        return BilateralActivityFeed(
            friendId: friendId,
            friendName: "Friend",
            netBalance: 100,
            currency: "INR",
            summaryText: "Owed ₹100",
            timeline: []
        )
    }

    func fetchGroups() async throws -> [GroupRead] {
        if let shouldThrowError { throw shouldThrowError }
        return mockGroups
    }

    func createGroup(name: String) async throws -> GroupRead {
        if let shouldThrowError { throw shouldThrowError }
        let group = GroupRead(id: UUID(), name: name, inviteCode: "ABCDEF", createdBy: UUID(), createdAt: Date())
        mockGroups.append(group)
        return group
    }

    func joinGroup(inviteCode: String) async throws -> GroupRead {
        if let shouldThrowError { throw shouldThrowError }
        return GroupRead(id: UUID(), name: "Joined Group", inviteCode: inviteCode, createdBy: UUID(), createdAt: Date())
    }

    func fetchGroupDetail(groupId: UUID) async throws -> GroupDetailRead {
        if let shouldThrowError { throw shouldThrowError }
        return GroupDetailRead(
            id: groupId,
            name: "Test Group",
            inviteCode: "ABCDEF",
            createdBy: UUID(),
            createdAt: Date(),
            members: [],
            totalSpending: 0
        )
    }

    func addGroupMember(groupId: UUID, identifier: String, name: String?, role: String) async throws -> GroupMemberRead {
        if let shouldThrowError { throw shouldThrowError }
        return GroupMemberRead(
            userId: UUID(),
            name: name ?? "Member",
            email: identifier.contains("@") ? identifier : "member@example.com",
            phone: nil,
            role: role,
            joinedAt: Date()
        )
    }

    func fetchGroupFeed(groupId: UUID, limit: Int, offset: Int) async throws -> GroupActivityFeed {
        if let shouldThrowError { throw shouldThrowError }
        return GroupActivityFeed(
            groupId: groupId,
            groupName: "Test Group",
            totalSpending: 0,
            currency: "INR",
            timeline: []
        )
    }

    func fetchExpenses(groupId: UUID?, scope: String?, limit: Int, offset: Int) async throws -> [ExpenseRead] {
        if let shouldThrowError { throw shouldThrowError }
        return mockExpenses
    }

    func fetchExpenseDetail(id: UUID) async throws -> ExpenseRead {
        if let shouldThrowError { throw shouldThrowError }
        guard let expense = mockExpenses.first(where: { $0.id == id }) else {
            throw APIError.httpError(statusCode: 404, message: "Expense not found")
        }
        return expense
    }

    func createExpense(_ payload: ExpenseCreate) async throws -> ExpenseRead {
        if let shouldThrowError { throw shouldThrowError }
        let expense = ExpenseRead(
            id: UUID(),
            groupId: payload.groupId,
            description: payload.description,
            amount: payload.amount,
            currency: payload.currency,
            payerId: payload.payerId,
            payerName: nil,
            category: payload.category,
            expenseDate: payload.expenseDate ?? Date(),
            isDeleted: false,
            createdAt: Date(),
            updatedAt: Date(),
            splits: []
        )
        mockExpenses.append(expense)
        return expense
    }

    func updateExpense(id: UUID, payload: ExpenseUpdate) async throws -> ExpenseRead {
        if let shouldThrowError { throw shouldThrowError }
        guard let index = mockExpenses.firstIndex(where: { $0.id == id }) else {
            throw APIError.httpError(statusCode: 404, message: "Expense not found")
        }
        let existing = mockExpenses[index]
        let updated = ExpenseRead(
            id: existing.id,
            groupId: existing.groupId,
            description: payload.description ?? existing.description,
            amount: payload.amount ?? existing.amount,
            currency: existing.currency,
            payerId: existing.payerId,
            payerName: existing.payerName,
            category: payload.category ?? existing.category,
            expenseDate: payload.expenseDate ?? existing.expenseDate,
            isDeleted: existing.isDeleted,
            createdAt: existing.createdAt,
            updatedAt: Date(),
            splits: existing.splits
        )
        mockExpenses[index] = updated
        return updated
    }

    func fetchSelfExpenses(limit: Int, offset: Int, category: String?, month: Int?, year: Int?) async throws -> SelfExpensesSummary {
        if let shouldThrowError { throw shouldThrowError }
        return mockSelfExpenses
    }

    func createSelfExpense(_ payload: SelfExpenseCreate) async throws -> ExpenseRead {
        if let shouldThrowError { throw shouldThrowError }
        let expense = ExpenseRead(
            id: UUID(),
            groupId: nil,
            description: payload.description,
            amount: payload.amount,
            currency: payload.currency,
            payerId: UUID(),
            payerName: nil,
            category: payload.category,
            expenseDate: payload.expenseDate ?? Date(),
            isDeleted: false,
            createdAt: Date(),
            updatedAt: Date(),
            splits: []
        )
        return expense
    }

    func deleteExpense(id: UUID) async throws {
        if let shouldThrowError { throw shouldThrowError }
        mockExpenses.removeAll { $0.id == id }
    }

    func fetchSettlements(friendId: UUID?, groupId: UUID?, limit: Int, offset: Int) async throws -> [SettlementRead] {
        if let shouldThrowError { throw shouldThrowError }
        return []
    }

    func createSettlement(_ payload: SettlementCreate) async throws -> SettlementRead {
        if let shouldThrowError { throw shouldThrowError }
        didCallCreateSettlement = true
        lastSettlementPayload = payload
        let settlement = SettlementRead(
            id: UUID(),
            payerId: UUID(),
            payerName: "You",
            payeeId: payload.payeeId,
            payeeName: "Friend",
            amount: payload.amount,
            currency: "INR",
            groupId: payload.groupId,
            paymentMethod: payload.paymentMethod,
            transactionReference: payload.transactionReference,
            notes: payload.notes,
            settlementDate: payload.settlementDate ?? Date(),
            isDeleted: false,
            createdAt: Date()
        )
        mockSettlement = settlement
        return settlement
    }

    func deleteSettlement(id: UUID) async throws {
        if let shouldThrowError { throw shouldThrowError }
    }
}
