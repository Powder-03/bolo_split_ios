//
//  VoiceModels.swift
//  BoloSplit
//
//  Codable models matching backend /voice/text and /voice/audio contracts.
//

import Foundation

struct VoiceCommandRequest: Codable, Sendable {
    let text: String
    let clientTimestampIso: String?
    let groupId: UUID?
}

struct VoiceIngestResponse: Codable, Equatable, Sendable {
    let status: String
    let actionType: String
    let count: Int
    let expenses: [ExpenseRead]
    let selfExpenses: [SelfExpenseRead]
    let settlement: SettlementRead?
    let balanceSummary: BalanceSummary?
    let spokenConfirmation: String?
    let isAmbiguous: Bool
    let clarificationPrompt: String?
    let errorCode: String?

    enum CodingKeys: String, CodingKey {
        case status
        case actionType
        case count
        case expenses
        case selfExpenses
        case settlement
        case balanceSummary
        case spokenConfirmation
        case isAmbiguous
        case clarificationPrompt
        case errorCode
    }

    init(
        status: String = "SUCCESS",
        actionType: String = "CREATE",
        count: Int = 1,
        expenses: [ExpenseRead] = [],
        selfExpenses: [SelfExpenseRead] = [],
        settlement: SettlementRead? = nil,
        balanceSummary: BalanceSummary? = nil,
        spokenConfirmation: String? = nil,
        isAmbiguous: Bool = false,
        clarificationPrompt: String? = nil,
        errorCode: String? = nil
    ) {
        self.status = status
        self.actionType = actionType
        self.count = count
        self.expenses = expenses
        self.selfExpenses = selfExpenses
        self.settlement = settlement
        self.balanceSummary = balanceSummary
        self.spokenConfirmation = spokenConfirmation
        self.isAmbiguous = isAmbiguous
        self.clarificationPrompt = clarificationPrompt
        self.errorCode = errorCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "SUCCESS"
        self.actionType = try container.decodeIfPresent(String.self, forKey: .actionType) ?? "CREATE"
        self.count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 1
        self.expenses = try container.decodeIfPresent([ExpenseRead].self, forKey: .expenses) ?? []
        self.selfExpenses = try container.decodeIfPresent([SelfExpenseRead].self, forKey: .selfExpenses) ?? []
        self.settlement = try container.decodeIfPresent(SettlementRead.self, forKey: .settlement)
        self.balanceSummary = try container.decodeIfPresent(BalanceSummary.self, forKey: .balanceSummary)
        self.spokenConfirmation = try container.decodeIfPresent(String.self, forKey: .spokenConfirmation)
        self.isAmbiguous = try container.decodeIfPresent(Bool.self, forKey: .isAmbiguous) ?? false
        self.clarificationPrompt = try container.decodeIfPresent(String.self, forKey: .clarificationPrompt)
        self.errorCode = try container.decodeIfPresent(String.self, forKey: .errorCode)
    }

    var normalizedAction: String {
        actionType.uppercased()
    }

    var mutatesLedger: Bool {
        normalizedAction != "GET"
    }

    var actionBadgeTitle: String {
        switch normalizedAction {
        case "CREATE", "MULTI_CREATE":
            return count > 1 ? "\(count) EXPENSES ADDED" : "EXPENSE ADDED"
        case "UPDATE":
            return "EXPENSE UPDATED"
        case "DELETE":
            return "EXPENSE DELETED"
        case "SETTLE":
            return "SETTLEMENT RECORDED"
        case "GET":
            return "BALANCE SUMMARY"
        default:
            return normalizedAction
        }
    }
}
