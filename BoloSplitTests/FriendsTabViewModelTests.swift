//
//  FriendsTabViewModelTests.swift
//  BoloSplitTests
//
//  Unit tests covering FriendsTabViewModel loading, balance formatting,
//  and error handling according to US-2.1 and US-8.1.
//

import XCTest
@testable import BoloSplit

@MainActor
final class FriendsTabViewModelTests: XCTestCase {
    private var mockLedger: MockLedgerService!
    private var viewModel: FriendsTabViewModel!

    override func setUp() {
        super.setUp()
        mockLedger = MockLedgerService()
        viewModel = FriendsTabViewModel(ledgerService: mockLedger)
    }

    override func tearDown() {
        viewModel = nil
        mockLedger = nil
        super.tearDown()
    }

    func testInitialStateIsEmpty() {
        XCTAssertNil(viewModel.balanceSummary)
        XCTAssertTrue(viewModel.friendRows.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadDataSuccess() async {
        let friendUserId = UUID()
        mockLedger.mockBalances = BalanceSummary(
            totalOwedToYou: 2000,
            totalYouOwe: 500,
            netTotal: 1500,
            balances: [
                UserBalance(
                    userId: friendUserId,
                    userName: "Sahaj",
                    netBalance: 1500
                )
            ]
        )
        mockLedger.mockFriends = [
            FriendRead(
                id: UUID(),
                userId: UUID(),
                friendId: friendUserId,
                friendName: "Sahaj",
                friendEmail: "sahaj@example.com",
                friendPhone: nil,
                nickname: "Bhaiya",
                aliases: ["sahaj", "bhaiya"],
                createdAt: Date()
            )
        ]

        await viewModel.loadData()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.balanceSummary)
        XCTAssertEqual(viewModel.balanceSummary?.netTotal, 1500)
        XCTAssertEqual(viewModel.friendRows.count, 1)

        let row = viewModel.friendRows[0]
        XCTAssertEqual(row.id, friendUserId)
        XCTAssertEqual(row.name, "Sahaj")
        XCTAssertEqual(row.nickname, "Bhaiya")
        XCTAssertEqual(row.netBalance, 1500)
    }

    func testLoadDataFailureSetsErrorMessage() async {
        mockLedger.shouldThrowError = APIError.httpError(statusCode: 500, message: "Internal server error")

        await viewModel.loadData()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.balanceSummary)
        XCTAssertTrue(viewModel.friendRows.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testAddFriendSuccess() async {
        let result = await viewModel.addFriend(
            name: "Rahul",
            email: "rahul@example.com",
            phone: nil,
            nickname: "Rahu",
            aliasesText: "rahu, dost"
        )

        switch result {
        case .success(let friend):
            XCTAssertEqual(friend.friendName, "Rahul")
            XCTAssertEqual(friend.friendEmail, "rahul@example.com")
            XCTAssertEqual(mockLedger.mockFriends.count, 1)
        case .failure(let error):
            XCTFail("Expected success but got \(error)")
        }
    }

    func testAddFriendValidationFailure() async {
        let result = await viewModel.addFriend(
            name: "",
            email: nil,
            phone: nil,
            nickname: nil,
            aliasesText: ""
        )

        switch result {
        case .success:
            XCTFail("Expected failure for empty identifier and name")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("email") || error.localizedDescription.contains("phone") || error.localizedDescription.contains("required") || error.localizedDescription.contains("422"))
        }
    }

    func testClearResetsState() async {
        mockLedger.mockBalances = BalanceSummary(
            totalOwedToYou: 100,
            totalYouOwe: 0,
            netTotal: 100,
            balances: []
        )
        await viewModel.loadData()
        XCTAssertNotNil(viewModel.balanceSummary)

        viewModel.clear()

        XCTAssertNil(viewModel.balanceSummary)
        XCTAssertTrue(viewModel.friendRows.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }
}
