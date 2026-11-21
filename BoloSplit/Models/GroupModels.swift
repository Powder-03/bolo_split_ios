//
//  GroupModels.swift
//  BoloSplit
//
//  Codable models for Groups, Members, and Group Activity Feeds.
//

import Foundation

struct GroupCreate: Codable, Sendable {
    let name: String
}

struct GroupRead: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let inviteCode: String
    let createdBy: UUID
    let createdAt: Date
}

struct GroupMemberRead: Codable, Identifiable, Equatable, Sendable {
    let userId: UUID
    let name: String
    let nickname: String?
    let email: String
    let phone: String?
    let role: String
    let joinedAt: Date

    var id: UUID { userId }

    var displayName: String {
        if let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nickname.isEmpty {
            return nickname
        }
        return name
    }

    init(
        userId: UUID,
        name: String,
        nickname: String? = nil,
        email: String,
        phone: String?,
        role: String,
        joinedAt: Date
    ) {
        self.userId = userId
        self.name = name
        self.nickname = nickname
        self.email = email
        self.phone = phone
        self.role = role
        self.joinedAt = joinedAt
    }
}

struct GroupDetailRead: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let inviteCode: String
    let createdBy: UUID
    let createdAt: Date
    let members: [GroupMemberRead]
    @JSONDecimal var totalSpending: Decimal
}

struct GroupMemberAdd: Codable, Sendable {
    let identifier: String
    let name: String?
    let role: String
}

struct GroupActivityFeed: Codable, Equatable, Sendable {
    let groupId: UUID
    let groupName: String
    @JSONDecimal var totalSpending: Decimal
    let currency: String
    let timeline: [ActivityTimelineItem]
}
