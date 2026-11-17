//
//  SettleUpViewModel.swift
//  BoloSplit
//
//  ViewModel validating and recording Settle Up payments via POST /settlements.
//

import Foundation
import Observation
import UIKit

@Observable
final class SettleUpViewModel {
    private let ledgerService: LedgerServiceProtocol
    private let onSettled: (() async -> Void)?

    let friendId: UUID
    let friendName: String
    let groupId: UUID?
    let netBalance: Decimal

    var amountText: String
    var paymentMethod: PaymentMethod = .upi
    var transactionReference: String = ""
    var notes: String = ""
    var settlementDate: Date = Date()

    var isSubmitting = false
    var errorMessage: String?

    init(
        friendId: UUID,
        friendName: String,
        netBalance: Decimal,
        groupId: UUID? = nil,
        ledgerService: LedgerServiceProtocol,
        onSettled: (() async -> Void)? = nil
    ) {
        self.friendId = friendId
        self.friendName = friendName
        self.netBalance = netBalance
        self.groupId = groupId
        self.ledgerService = ledgerService
        self.onSettled = onSettled

        if netBalance < 0 {
            let owed = NSDecimalNumber(decimal: abs(netBalance)).doubleValue
            self.amountText = String(format: "%.2f", owed)
        } else {
            self.amountText = ""
        }
    }

    var parsedAmount: Decimal? {
        Decimal(string: amountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var isValid: Bool {
        (parsedAmount ?? 0) > 0
    }

    func submitSettlement() async -> Bool {
        guard let amount = parsedAmount, amount > 0 else {
            errorMessage = "Please enter a valid payment amount."
            return false
        }

        let cleanRef = transactionReference.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = SettlementCreate(
            payeeId: friendId,
            amount: amount,
            currency: "INR",
            groupId: groupId,
            paymentMethod: paymentMethod.rawValue,
            transactionReference: cleanRef.isEmpty ? nil : cleanRef,
            notes: cleanNotes.isEmpty ? "Paid via \(paymentMethod.displayName)" : cleanNotes,
            settlementDate: settlementDate
        )

        isSubmitting = true
        errorMessage = nil

        do {
            _ = try await ledgerService.createSettlement(payload)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isSubmitting = false
            await onSettled?()
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
}
