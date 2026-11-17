//
//  FriendModels.swift
//  BoloSplit
//
//  Codable models for Friends and 1-on-1 / Group Activity Timelines.
//

import Foundation

struct FriendCreate: Codable, Sendable {
    let friendEmail: String?
    let friendPhone: String?
    let friendName: String?
    let nickname: String?
    let aliases: [String]
}

struct FriendRead: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    let friendId: UUID
    let friendName: String
    let friendEmail: String
    let friendPhone: String?
    let nickname: String?
    let aliases: [String]
    let createdAt: Date
}

struct ActivityTimelineItem: Codable, Identifiable, Equatable, Sendable {
    let type: String // "EXPENSE" or "SETTLEMENT"
    let id: UUID
    let date: Date
    let description: String
    @JSONDecimal var totalAmount: Decimal
    let currency: String
    let payerId: UUID
    let payerName: String
    let payeeId: UUID?
    let payeeName: String?
    let groupId: UUID?
    @OptionalJSONDecimal var yourShare: Decimal?
    @JSONDecimal var yourNetImpact: Decimal

    var isSettlement: Bool {
        type.uppercased() == "SETTLEMENT"
    }
}

struct BilateralActivityFeed: Codable, Equatable, Sendable {
    let friendId: UUID
    let friendName: String
    @JSONDecimal var netBalance: Decimal
    let currency: String
    let summaryText: String
    let timeline: [ActivityTimelineItem]
}
