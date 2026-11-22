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
            async let expensesTask = ledgerService.fetchExpenses(groupId: nil, scope: nil, limit: 50, offset: 0)
            async let settlementsTask = ledgerService.fetchSettlements(friendId: nil, groupId: nil, limit: 50, offset: 0)
            async let friendsTask = try? ledgerService.fetchFriends()

            let (expenses, settlements, friends) = try await (expensesTask, settlementsTask, friendsTask)
            var friendNames: [UUID: String] = [:]
            if let friends {
                for friend in friends {
                    friendNames[friend.friendId] = friend.displayName
                }
            }

            let expenseEntries = expenses.map { exp in
                let subtitle: String
                if exp.isSoloExpense {
                    subtitle = "Self (Personal) • \(exp.category?.capitalized ?? "General")"
                } else if exp.groupId == nil, exp.splits.count == 1,
                          let targetName = friendNames[exp.splits[0].userId] {
                    subtitle = "\(exp.payerName ?? "Someone") paid \(CurrencyFormatter.formatINR(exp.amount)) • For \(targetName)"
                } else {
                    subtitle = "\(exp.payerName ?? "Someone") paid \(CurrencyFormatter.formatINR(exp.amount))"
                }
                return ActivityFeedEntry(
                    id: exp.id,
                    date: exp.expenseDate,
                    title: exp.description,
                    subtitle: subtitle,
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

    func deleteEntry(_ entry: ActivityFeedEntry) async {
        do {
            switch entry.kind {
            case .expense(let expense):
                try await ledgerService.deleteExpense(id: expense.id)
            case .settlement(let settlement):
                try await ledgerService.deleteSettlement(id: settlement.id)
            }
            entries.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
