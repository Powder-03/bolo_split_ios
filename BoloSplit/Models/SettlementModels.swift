//
//  SettlementModels.swift
//  BoloSplit
//
//  Codable models for Settlements ('Settle Up').
//

import Foundation

enum PaymentMethod: String, CaseIterable, Identifiable, Codable, Sendable {
    case upi = "UPI"
    case gpay = "GPAY"
    case phonepe = "PHONEPE"
    case cash = "CASH"
    case netBanking = "NET_BANKING"
    case other = "OTHER"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upi: return "UPI"
        case .gpay: return "Google Pay"
        case .phonepe: return "PhonePe"
        case .cash: return "Cash"
        case .netBanking: return "Net Banking"
        case .other: return "Other"
        }
    }
}

struct SettlementCreate: Codable, Sendable {
    let payeeId: UUID
    @JSONDecimal var amount: Decimal
    let currency: String
    let groupId: UUID?
    let paymentMethod: String
    let transactionReference: String?
    let notes: String?
    let settlementDate: Date?
}

struct SettlementRead: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let payerId: UUID
    let payerName: String?
    let payeeId: UUID
    let payeeName: String?
    @JSONDecimal var amount: Decimal
    let currency: String
    let groupId: UUID?
    let paymentMethod: String
    let transactionReference: String?
    let notes: String?
    let settlementDate: Date
    let isDeleted: Bool
    let createdAt: Date
}
