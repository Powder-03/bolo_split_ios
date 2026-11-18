//
//  ExpenseDetailViewModel.swift
//  BoloSplit
//
//  ViewModel loading expense splits, handling PATCH edits, and DELETE soft-deletion.
//

import Foundation
import Observation

@Observable
final class ExpenseDetailViewModel {
    private let ledgerService: LedgerServiceProtocol
    private let onLedgerMutated: (() async -> Void)?

    let expenseId: UUID
    var expense: ExpenseRead?
    var knownUserNames: [UUID: String]
    var isLoading = false
    var isSaving = false
    var isDeleting = false
    var errorMessage: String?

    init(
        expenseId: UUID,
        initialExpense: ExpenseRead? = nil,
        knownUserNames: [UUID: String] = [:],
        ledgerService: LedgerServiceProtocol,
        onLedgerMutated: (() async -> Void)? = nil
    ) {
        self.expenseId = expenseId
        self.expense = initialExpense
        self.knownUserNames = knownUserNames
        self.ledgerService = ledgerService
        self.onLedgerMutated = onLedgerMutated
    }

    func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            async let expenseTask = ledgerService.fetchExpenseDetail(id: expenseId)
            async let friendsTask = try? ledgerService.fetchFriends()

            let loadedExpense = try await expenseTask
            expense = loadedExpense

            if let friends = await friendsTask {
                for friend in friends {
                    knownUserNames[friend.friendId] = friend.friendName
                    knownUserNames[friend.userId] = "You"
                }
            }
            if let payerName = loadedExpense.payerName, knownUserNames[loadedExpense.payerId] == nil {
                knownUserNames[loadedExpense.payerId] = payerName
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func displayName(for userId: UUID) -> String {
        if let name = knownUserNames[userId] {
            return name
        }
        if let expense, userId == expense.payerId, let payerName = expense.payerName {
            return payerName
        }
        return "Member (\(userId.uuidString.prefix(4)))"
    }

    func updateExpense(
        description: String,
        amount: Decimal,
        category: String,
        date: Date
    ) async -> Bool {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, amount > 0 else {
            errorMessage = "Please provide a description and valid amount."
            return false
        }

        isSaving = true
        errorMessage = nil

        do {
            let payload = ExpenseUpdate(
                description: trimmed,
                amount: amount,
                category: category.lowercased(),
                expenseDate: date
            )
            expense = try await ledgerService.updateExpense(id: expenseId, payload: payload)
            isSaving = false
            await onLedgerMutated?()
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    func deleteExpense() async -> Bool {
        isDeleting = true
        errorMessage = nil
        do {
            try await ledgerService.deleteExpense(id: expenseId)
            isDeleting = false
            await onLedgerMutated?()
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
    }
}
