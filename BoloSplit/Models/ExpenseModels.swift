//
//  ExpenseModels.swift
//  BoloSplit
//
//  Codable models for Verified Ledger Expenses and Splits.
//

import Foundation

struct ExpenseSplitCreate: Codable, Sendable {
    let userId: UUID
    @JSONDecimal var owedAmount: Decimal
    let splitType: String
    @OptionalJSONDecimal var splitValue: Decimal?
}

struct ExpenseSplitRead: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let expenseId: UUID
    let userId: UUID
    @JSONDecimal var owedAmount: Decimal
    let splitType: String
    @OptionalJSONDecimal var splitValue: Decimal?
    let createdAt: Date
}

struct ExpenseCreate: Codable, Sendable {
    let description: String
    @JSONDecimal var amount: Decimal
    let currency: String
    let payerId: UUID
    let groupId: UUID?
    let category: String?
    let expenseDate: Date?
    let splits: [ExpenseSplitCreate]
}

struct ExpenseUpdate: Codable, Sendable {
    let description: String?
    @OptionalJSONDecimal var amount: Decimal?
    let category: String?
    let expenseDate: Date?
}

struct ExpenseRead: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let groupId: UUID?
    let description: String
    @JSONDecimal var amount: Decimal
    let currency: String
    let payerId: UUID
    let payerName: String?
    let category: String?
    let expenseDate: Date
    let isDeleted: Bool
    let createdAt: Date
    let updatedAt: Date
    let splits: [ExpenseSplitRead]

    /// True only when the expense is non-group and every split (if any) belongs to the payer.
    var isSoloExpense: Bool {
        groupId == nil && (splits.isEmpty || splits.allSatisfy { $0.userId == payerId })
    }
}

// MARK: - Solo / Self Expenses

struct SelfExpenseCreate: Codable, Sendable {
    let description: String
    @JSONDecimal var amount: Decimal
    let currency: String
    let category: String?
    let expenseDate: Date?
}

struct SelfExpenseUpdate: Codable, Sendable {
    let description: String?
    @OptionalJSONDecimal var amount: Decimal?
    let category: String?
    let expenseDate: Date?
}

struct SelfExpenseRead: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    let description: String
    @JSONDecimal var amount: Decimal
    let currency: String
    let category: String?
    let expenseDate: Date
    let isDeleted: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct SelfCategoryStat: Codable, Identifiable, Equatable, Sendable {
    let category: String
    @JSONDecimal var totalAmount: Decimal
    let count: Int

    var id: String { category }
}

struct SelfExpensesSummary: Codable, Equatable, Sendable {
    @JSONDecimal var totalSpending: Decimal
    @JSONDecimal var thisMonthSpending: Decimal
    let totalCount: Int
    let currency: String
    let categories: [SelfCategoryStat]
    let expenses: [SelfExpenseRead]
}
