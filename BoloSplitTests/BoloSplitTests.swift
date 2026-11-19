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
}
