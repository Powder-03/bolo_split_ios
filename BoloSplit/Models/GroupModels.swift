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
    let email: String
    let phone: String?
    let role: String
    let joinedAt: Date

    var id: UUID { userId }
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
