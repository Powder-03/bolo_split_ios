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
        XCTAssertTrue(viewModel.friends.isEmpty)
        XCTAssertTrue(viewModel.friendRows.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testUpdateFriendAliasesSuccessAndClearNickname() async {
        let f1Id = UUID()
        mockLedger.mockFriends = [
            FriendRead(
                id: UUID(),
                userId: UUID(),
                friendId: f1Id,
                friendName: "Rishabh",
                friendEmail: "r1@example.com",
                friendPhone: "+919800000001",
                nickname: nil,
                aliases: [],
                createdAt: Date()
            )
        ]
        await viewModel.loadData()

        let updateRes = await viewModel.updateFriendAliases(
            friendId: f1Id,
            nickname: "Rishabh Office",
            aliases: ["Office Bro", "rishabh office", "office bro"]
        )

        switch updateRes {
        case .success(let updated):
            XCTAssertEqual(updated.nickname, "Rishabh Office")
            XCTAssertEqual(updated.aliases, ["office bro", "rishabh office"])
            XCTAssertEqual(viewModel.friendRows.first?.displayName, "Rishabh Office")
        case .failure(let error):
            XCTFail("Expected success but got \(error)")
        }

        let clearRes = await viewModel.updateFriendAliases(
            friendId: f1Id,
            nickname: "   ",
            aliases: []
        )

        switch clearRes {
        case .success(let cleared):
            XCTAssertNil(cleared.nickname)
            XCTAssertTrue(cleared.aliases.isEmpty)
            XCTAssertEqual(viewModel.friendRows.first?.displayName, "Rishabh")
        case .failure(let error):
            XCTFail("Expected clear success but got \(error)")
        }
    }

    func testUpdateFriendAliasesDetectsConflictAcrossFriends() async {
        let r1Id = UUID()
        let r2Id = UUID()
        mockLedger.mockFriends = [
            FriendRead(
                id: UUID(),
                userId: UUID(),
                friendId: r1Id,
                friendName: "Rishabh",
                friendEmail: "r1@example.com",
                friendPhone: "+919800000001",
                nickname: "Rishabh Office",
                aliases: ["office bro"],
                createdAt: Date()
            ),
            FriendRead(
                id: UUID(),
                userId: UUID(),
                friendId: r2Id,
                friendName: "Rishabh",
                friendEmail: "r2@example.com",
                friendPhone: "+919800000002",
                nickname: "Rishabh Flat",
                aliases: ["flatmate"],
                createdAt: Date()
            )
        ]
        await viewModel.loadData()

        let localConflict = viewModel.conflictingFriend(
            forNickname: "rishabh office",
            aliases: ["new alias"],
            excludingFriendId: r2Id
        )
        XCTAssertEqual(localConflict?.friend.friendId, r1Id)
        XCTAssertEqual(localConflict?.label, "rishabh office")

        let serverConflict = await viewModel.updateFriendAliases(
            friendId: r2Id,
            nickname: "Rishabh Flat",
            aliases: ["office bro"]
        )
        switch serverConflict {
        case .success:
            XCTFail("Expected 409 conflict failure")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("already assigned"))
        }
    }
}
