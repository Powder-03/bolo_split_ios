//
//  BalanceModels.swift
//  BoloSplit
//
//  Codable models matching backend /health and /balances schemas.
//

import Foundation

struct HealthResponse: Codable, Equatable, Sendable {
    let status: String
    let service: String
    let environment: String
}

struct UserBalance: Codable, Identifiable, Equatable, Sendable {
    let userId: UUID
    let userName: String
    let nickname: String?
    @JSONDecimal var netBalance: Decimal

    var id: UUID { userId }

    var displayName: String {
        if let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nickname.isEmpty {
            return nickname
        }
        return userName
    }

    init(userId: UUID, userName: String, nickname: String? = nil, netBalance: Decimal) {
        self.userId = userId
        self.userName = userName
        self.nickname = nickname
        self._netBalance = JSONDecimal(wrappedValue: netBalance)
    }
}

struct BalanceSummary: Codable, Equatable, Sendable {
    @JSONDecimal var totalOwedToYou: Decimal
    @JSONDecimal var totalYouOwe: Decimal
    @JSONDecimal var netTotal: Decimal
    let balances: [UserBalance]
}
