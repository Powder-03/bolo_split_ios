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
    @JSONDecimal var netBalance: Decimal

    var id: UUID { userId }
}

struct BalanceSummary: Codable, Equatable, Sendable {
    @JSONDecimal var totalOwedToYou: Decimal
    @JSONDecimal var totalYouOwe: Decimal
    @JSONDecimal var netTotal: Decimal
    let balances: [UserBalance]
}
