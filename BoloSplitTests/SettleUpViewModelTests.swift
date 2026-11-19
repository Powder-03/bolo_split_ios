//
//  SettleUpViewModelTests.swift
//  BoloSplitTests
//
//  Unit tests covering SettleUpViewModel validation, payment recording,
//  and callback invocation (US-7.1, US-8.1).
//

import XCTest
@testable import BoloSplit

@MainActor
final class SettleUpViewModelTests: XCTestCase {
    private var mockLedger: MockLedgerService!
    private let friendId = UUID()
    private let friendName = "Sahaj"
    private var settledCallbackCalled = false

    override func setUp() {
        super.setUp()
        mockLedger = MockLedgerService()
        settledCallbackCalled = false
    }

    override func tearDown() {
        mockLedger = nil
        super.tearDown()
    }

    func testInitialStatePreFillsWhenOwed() {
        let viewModel = SettleUpViewModel(
            friendId: friendId,
            friendName: friendName,
            netBalance: -450.50,
            groupId: nil,
            ledgerService: mockLedger
        )

        XCTAssertEqual(viewModel.friendId, friendId)
        XCTAssertEqual(viewModel.friendName, "Sahaj")
        XCTAssertEqual(viewModel.amountText, "450.50")
        XCTAssertEqual(viewModel.paymentMethod, .upi)
        XCTAssertTrue(viewModel.isValid)
    }

    func testInitialStateEmptyWhenOwedToYou() {
        let viewModel = SettleUpViewModel(
            friendId: friendId,
            friendName: friendName,
            netBalance: 500,
            groupId: nil,
            ledgerService: mockLedger
        )

        XCTAssertEqual(viewModel.amountText, "")
        XCTAssertFalse(viewModel.isValid)
    }

    func testValidationFailsForZeroOrNegativeAmount() async {
        let viewModel = SettleUpViewModel(
            friendId: friendId,
            friendName: friendName,
            netBalance: -100,
            groupId: nil,
            ledgerService: mockLedger
        )

        viewModel.amountText = "0"
        let successZero = await viewModel.submitSettlement()
        XCTAssertFalse(successZero)
        XCTAssertEqual(viewModel.errorMessage, "Please enter a valid payment amount.")

        viewModel.amountText = "-50"
        let successNegative = await viewModel.submitSettlement()
        XCTAssertFalse(successNegative)
        XCTAssertEqual(viewModel.errorMessage, "Please enter a valid payment amount.")
    }

    func testSubmitSettlementSuccess() async {
        let viewModel = SettleUpViewModel(
            friendId: friendId,
            friendName: friendName,
            netBalance: -250,
            groupId: nil,
            ledgerService: mockLedger,
            onSettled: { [weak self] in
                self?.settledCallbackCalled = true
            }
        )

        viewModel.amountText = "250.00"
        viewModel.paymentMethod = .gpay
        viewModel.transactionReference = "UPI12345678"

        let success = await viewModel.submitSettlement()

        XCTAssertTrue(success)
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(mockLedger.didCallCreateSettlement)
        XCTAssertEqual(mockLedger.lastSettlementPayload?.amount, 250)
        XCTAssertEqual(mockLedger.lastSettlementPayload?.paymentMethod, "GPAY")
        XCTAssertEqual(mockLedger.lastSettlementPayload?.transactionReference, "UPI12345678")
        XCTAssertTrue(settledCallbackCalled)
    }

    func testSubmitSettlementFailureSetsErrorMessage() async {
        mockLedger.shouldThrowError = APIError.httpError(statusCode: 400, message: "Duplicate settlement reference")

        let viewModel = SettleUpViewModel(
            friendId: friendId,
            friendName: friendName,
            netBalance: -300,
            groupId: nil,
            ledgerService: mockLedger
        )

        viewModel.amountText = "300"
        let success = await viewModel.submitSettlement()

        XCTAssertFalse(success)
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Duplicate settlement") == true)
        XCTAssertFalse(settledCallbackCalled)
    }
}
