//
//  ActivityTabViewModel.swift
//  BoloSplit
//
//  ViewModel merging verified expenses and settlements into a unified Splitwise Activity feed.
//

import Foundation
import Observation

enum ActivityEntryKind: Equatable {
    case expense(ExpenseRead)
    case settlement(SettlementRead)
}

struct ActivityFeedEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let title: String
    let subtitle: String
    let amount: Decimal
    let category: String?
    let kind: ActivityEntryKind

    var isSettlement: Bool {
        if case .settlement = kind { return true }
        return false
    }
}

@Observable
final class ActivityTabViewModel {
    private let ledgerService: LedgerServiceProtocol

    var entries: [ActivityFeedEntry] = []
    var isLoading = false
    var errorMessage: String?
    private var hasLoadedOnce = false

    init(ledgerService: LedgerServiceProtocol) {
        self.ledgerService = ledgerService
    }

    func loadActivity() async {
        isLoading = true
        errorMessage = nil
        do {
            async let expensesTask = ledgerService.fetchExpenses(groupId: nil, limit: 50, offset: 0)
            async let settlementsTask = ledgerService.fetchSettlements(friendId: nil, groupId: nil, limit: 50, offset: 0)

            let (expenses, settlements) = try await (expensesTask, settlementsTask)

            let expenseEntries = expenses.map { exp in
                ActivityFeedEntry(
                    id: exp.id,
                    date: exp.expenseDate,
                    title: exp.description,
                    subtitle: "\(exp.payerName ?? "Someone") paid \(CurrencyFormatter.formatINR(exp.amount))",
                    amount: exp.amount,
                    category: exp.category,
                    kind: .expense(exp)
                )
            }

            let settlementEntries = settlements.map { stl in
                let payer = stl.payerName ?? "Someone"
                let payee = stl.payeeName ?? "friend"
                return ActivityFeedEntry(
                    id: stl.id,
                    date: stl.settlementDate,
                    title: "\(payer) paid \(payee)",
                    subtitle: "Settled via \(stl.paymentMethod)",
                    amount: stl.amount,
                    category: nil,
                    kind: .settlement(stl)
                )
            }

            entries = (expenseEntries + settlementEntries).sorted { $0.date > $1.date }
            hasLoadedOnce = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadIfNeeded() async {
        if !hasLoadedOnce {
            await loadActivity()
        }
    }

    func clear() {
        entries = []
        errorMessage = nil
        hasLoadedOnce = false
    }
}
