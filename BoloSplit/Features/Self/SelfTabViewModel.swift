//
//  SelfTabViewModel.swift
//  BoloSplit
//
//  ViewModel for strictly solo / personal expenses, monthly spending & category stats.
//

import Foundation
import Observation

@Observable
final class SelfTabViewModel {
    private let ledgerService: LedgerServiceProtocol
    private let onLedgerMutated: (() async -> Void)?

    var summary: SelfExpensesSummary?
    var selectedCategory: String?
    var isLoading = false
    var isSubmitting = false
    var errorMessage: String?
    private var hasLoadedOnce = false

    init(
        ledgerService: LedgerServiceProtocol,
        onLedgerMutated: (() async -> Void)? = nil
    ) {
        self.ledgerService = ledgerService
        self.onLedgerMutated = onLedgerMutated
    }

    var expenses: [ExpenseRead] {
        summary?.expenses ?? []
    }

    var categories: [SelfCategoryStat] {
        summary?.categories ?? []
    }

    func loadSelfExpenses() async {
        isLoading = true
        errorMessage = nil
        do {
            summary = try await ledgerService.fetchSelfExpenses(
                limit: 50,
                offset: 0,
                category: selectedCategory,
                month: nil,
                year: nil
            )
            hasLoadedOnce = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadIfNeeded() async {
        if !hasLoadedOnce {
            await loadSelfExpenses()
        }
    }

    func selectCategory(_ category: String?) async {
        let normalized = category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        selectedCategory = (selectedCategory == normalized) ? nil : normalized
        await loadSelfExpenses()
    }

    func addSelfExpense(
        description: String,
        amount: Decimal,
        category: String,
        date: Date
    ) async -> Bool {
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDesc.isEmpty, amount > 0 else {
            errorMessage = "Please enter a description and valid amount."
            return false
        }

        isSubmitting = true
        errorMessage = nil
        do {
            let payload = SelfExpenseCreate(
                description: trimmedDesc,
                amount: amount,
                currency: "INR",
                category: category.lowercased(),
                expenseDate: date
            )
            _ = try await ledgerService.createSelfExpense(payload)
            isSubmitting = false
            await loadSelfExpenses()
            await onLedgerMutated?()
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }

    func deleteExpense(_ expense: ExpenseRead) async {
        do {
            try await ledgerService.deleteExpense(id: expense.id)
            await loadSelfExpenses()
            await onLedgerMutated?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        summary = nil
        selectedCategory = nil
        errorMessage = nil
        hasLoadedOnce = false
    }
}
