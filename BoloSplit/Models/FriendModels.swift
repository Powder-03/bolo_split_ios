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

    var displayName: String {
        if let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nickname.isEmpty {
            return nickname
        }
        return friendName
    }
}

struct FriendUpdate: Codable, Equatable, Sendable {
    let nickname: String?
    let aliases: [String]?
    private let includeNickname: Bool

    init(nickname: String?, aliases: [String]? = nil, includeNickname: Bool = true) {
        self.nickname = nickname
        self.aliases = aliases
        self.includeNickname = includeNickname
    }

    enum CodingKeys: String, CodingKey {
        case nickname
        case aliases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        self.aliases = try container.decodeIfPresent([String].self, forKey: .aliases)
        self.includeNickname = container.contains(.nickname)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if includeNickname {
            try container.encode(nickname, forKey: .nickname)
        }
        if let aliases {
            try container.encode(aliases, forKey: .aliases)
        }
    }
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
    let nickname: String?
    @JSONDecimal var netBalance: Decimal
    let currency: String
    let summaryText: String
    let timeline: [ActivityTimelineItem]

    init(
        friendId: UUID,
        friendName: String,
        nickname: String? = nil,
        netBalance: Decimal,
        currency: String,
        summaryText: String,
        timeline: [ActivityTimelineItem]
    ) {
        self.friendId = friendId
        self.friendName = friendName
        self.nickname = nickname
        self._netBalance = JSONDecimal(wrappedValue: netBalance)
        self.currency = currency
        self.summaryText = summaryText
        self.timeline = timeline
    }

    var displayName: String {
        if let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nickname.isEmpty {
            return nickname
        }
        return friendName
    }
}
