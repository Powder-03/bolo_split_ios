//
//  BoloSplitTests.swift
//  BoloSplitTests
//
//  Additional unit tests for paise rounding, FastAPI JSONCoders, and deep link routing.
//

import Foundation
import XCTest
@testable import BoloSplit

@MainActor
final class LedgerMathAndRoutingTests: XCTestCase {
    func testEqualSplitPaiseRoundingMatchesTotal() {
        let p1 = UUID()
        let p2 = UUID()
        let p3 = UUID()

        let splits = ManualExpenseFormViewModel.calculateEqualSplits(
            amount: Decimal(string: "100.00")!,
            participantIDs: [p1, p2, p3],
            payerId: p1
        )

        XCTAssertEqual(splits.count, 3)
        let sum = splits.reduce(Decimal.zero) { $0 + $1.owedAmount }
        XCTAssertEqual(sum, Decimal(string: "100.00"))
    }

    func testFastAPIJSONDecodingHandlesMicrosecondDatesAndDecimalStrings() throws {
        let json = """
        {
          "total_owed_to_you": "1250.50",
          "total_you_owe": 200.0,
          "net_total": "1050.50",
          "balances": []
        }
        """.data(using: .utf8)!

        let summary = try JSONCoders.decoder.decode(BalanceSummary.self, from: json)
        XCTAssertEqual(summary.totalOwedToYou, Decimal(string: "1250.50"))
        XCTAssertEqual(summary.totalYouOwe, Decimal(200))
        XCTAssertNotNil(DateParser.parseISO8601("2026-11-18T14:22:09.123456+00:00"))
    }

    func testDeepLinkQueuesVoiceOverlayWhenUnauthenticated() {
        let env = AppEnvironment()
        let url = URL(string: "bolosplit://voice")!

        env.handleDeepLink(url)

        XCTAssertTrue(env.pendingVoiceDeepLink)
    }

    func testFriendUpdateEncodesNullNicknameWhenCleared() throws {
        let payload = FriendUpdate(nickname: nil, aliases: ["flatmate"], includeNickname: true)
        let data = try JSONCoders.encoder.encode(payload)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(obj)
        XCTAssertTrue(obj?["nickname"] is NSNull)
        XCTAssertEqual(obj?["aliases"] as? [String], ["flatmate"])
    }

    func testBalanceAndGroupMemberDecodeOptionalNickname() throws {
        let balanceJSON = """
        {
          "user_id": "11111111-1111-1111-1111-111111111111",
          "user_name": "Rishabh",
          "nickname": "Rishabh Office",
          "net_balance": "200.00"
        }
        """.data(using: .utf8)!
        let bal = try JSONCoders.decoder.decode(UserBalance.self, from: balanceJSON)
        XCTAssertEqual(bal.nickname, "Rishabh Office")
        XCTAssertEqual(bal.displayName, "Rishabh Office")

        let memberJSON = """
        {
          "user_id": "22222222-2222-2222-2222-222222222222",
          "name": "Rishabh",
          "nickname": "Rishabh Flat",
          "email": "r2@example.com",
          "phone": "+919822222222",
          "role": "member",
          "joined_at": "2026-11-21T10:00:00+00:00"
        }
        """.data(using: .utf8)!
        let member = try JSONCoders.decoder.decode(GroupMemberRead.self, from: memberJSON)
        XCTAssertEqual(member.nickname, "Rishabh Flat")
        XCTAssertEqual(member.displayName, "Rishabh Flat")
    }

    func testOnFriendSingleSplitExpenseIsNotClassifiedAsSolo() async {
        let meId = UUID()
        let rishabhId = UUID()
        let expenseId = UUID()

        let onFriend = ExpenseRead(
            id: expenseId,
            groupId: nil,
            description: "Lunch",
            amount: Decimal(500),
            currency: "INR",
            payerId: meId,
            payerName: "Me",
            category: "food",
            expenseDate: Date(),
            isDeleted: false,
            createdAt: Date(),
            updatedAt: Date(),
            splits: [
                ExpenseSplitRead(
                    id: UUID(),
                    expenseId: expenseId,
                    userId: rishabhId,
                    owedAmount: Decimal(500),
                    splitType: "EQUAL",
                    splitValue: nil,
                    createdAt: Date()
                )
            ]
        )
        XCTAssertFalse(onFriend.isSoloExpense)

        let soloExpense = ExpenseRead(
            id: UUID(),
            groupId: nil,
            description: "Petrol",
            amount: Decimal(500),
            currency: "INR",
            payerId: meId,
            payerName: "Me",
            category: "fuel",
            expenseDate: Date(),
            isDeleted: false,
            createdAt: Date(),
            updatedAt: Date(),
            splits: [
                ExpenseSplitRead(
                    id: UUID(),
                    expenseId: expenseId,
                    userId: meId,
                    owedAmount: Decimal(500),
                    splitType: "EQUAL",
                    splitValue: nil,
                    createdAt: Date()
                )
            ]
        )
        XCTAssertTrue(soloExpense.isSoloExpense)

        let mockLedger = MockLedgerService()
        mockLedger.mockFriends = [
            FriendRead(
                id: UUID(),
                userId: meId,
                friendId: rishabhId,
                friendName: "Rishabh",
                friendEmail: "rishabh@example.com",
                friendPhone: nil,
                nickname: "Rishabh Office",
                aliases: [],
                createdAt: Date()
            )
        ]
        mockLedger.mockExpenses = [onFriend, soloExpense]

        let activityVM = ActivityTabViewModel(ledgerService: mockLedger)
        await activityVM.loadActivity()

        XCTAssertEqual(activityVM.entries.count, 2)
        let friendEntry = activityVM.entries.first { $0.id == onFriend.id }
        let soloEntry = activityVM.entries.first { $0.id == soloExpense.id }
        XCTAssertTrue(friendEntry?.subtitle.contains("For Rishabh Office") ?? false)
        XCTAssertFalse(friendEntry?.subtitle.contains("Self") ?? true)
        XCTAssertTrue(soloEntry?.subtitle.hasPrefix("Self (Personal)") ?? false)
    }
}
