//
//  ManualExpenseFormView.swift
//  BoloSplit
//
//  Manual expense creation sheet with Equal and Exact/Custom split modes.
//

import Foundation
import Observation
import SwiftUI
import UIKit

struct ExpenseParticipant: Identifiable, Hashable {
    let id: UUID
    let name: String
    let isCurrentUser: Bool
}

enum ManualSplitMode: String, CaseIterable, Identifiable {
    case equal = "Equal Split"
    case exact = "Exact Amounts"

    var id: String { rawValue }
}

@Observable
final class ManualExpenseFormViewModel {
    private let ledgerService: LedgerServiceProtocol
    private let onCreated: (() async -> Void)?

    let groupId: UUID?
    let groupName: String?
    let availableParticipants: [ExpenseParticipant]

    var description: String = ""
    var amountText: String = ""
    var category: String = "general"
    var expenseDate: Date = Date()
    var payerId: UUID
    var splitMode: ManualSplitMode = .equal
    var selectedParticipantIDs: Set<UUID>
    var exactAmountsByUserID: [UUID: String] = [:]

    var isSubmitting = false
    var errorMessage: String?

    init(
        groupId: UUID? = nil,
        groupName: String? = nil,
        participants: [ExpenseParticipant],
        ledgerService: LedgerServiceProtocol,
        onCreated: (() async -> Void)? = nil
    ) {
        self.groupId = groupId
        self.groupName = groupName
        self.availableParticipants = participants
        self.ledgerService = ledgerService
        self.onCreated = onCreated

        let defaultPayer = participants.first(where: { $0.isCurrentUser })?.id
            ?? participants.first?.id
            ?? UUID()
        self.payerId = defaultPayer
        self.selectedParticipantIDs = Set(participants.map(\.id))

        for participant in participants {
            exactAmountsByUserID[participant.id] = ""
        }
    }

    var parsedAmount: Decimal? {
        Decimal(string: amountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var exactSum: Decimal {
        availableParticipants.reduce(Decimal.zero) { partial, person in
            guard let raw = exactAmountsByUserID[person.id],
                  let val = Decimal(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                  val > 0 else {
                return partial
            }
            return partial + val
        }
    }

    var exactRemaining: Decimal {
        (parsedAmount ?? 0) - exactSum
    }

    var isValid: Bool {
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let total = parsedAmount,
              total > 0,
              !availableParticipants.isEmpty else {
            return false
        }

        switch splitMode {
        case .equal:
            return !selectedParticipantIDs.isEmpty
        case .exact:
            return exactRemaining == 0 && exactSum == total
        }
    }

    func toggleParticipant(_ id: UUID) {
        if selectedParticipantIDs.contains(id) {
            if selectedParticipantIDs.count > 1 {
                selectedParticipantIDs.remove(id)
            }
        } else {
            selectedParticipantIDs.insert(id)
        }
    }

    func submit() async -> Bool {
        guard let total = parsedAmount, total > 0 else {
            errorMessage = "Enter a valid expense amount."
            return false
        }

        let splits: [ExpenseSplitCreate]
        switch splitMode {
        case .equal:
            let orderedIDs = availableParticipants
                .map(\.id)
                .filter { selectedParticipantIDs.contains($0) }
            guard !orderedIDs.isEmpty else {
                errorMessage = "Select at least one participant."
                return false
            }
            splits = Self.calculateEqualSplits(amount: total, participantIDs: orderedIDs, payerId: payerId)

        case .exact:
            guard exactRemaining == 0 else {
                errorMessage = "Exact splits must sum to \(CurrencyFormatter.formatINR(total))."
                return false
            }
            splits = availableParticipants.compactMap { person in
                guard let raw = exactAmountsByUserID[person.id],
                      let val = Decimal(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                      val > 0 else {
                    return nil
                }
                return ExpenseSplitCreate(
                    userId: person.id,
                    owedAmount: val,
                    splitType: "EXACT",
                    splitValue: val
                )
            }
        }

        let payload = ExpenseCreate(
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: total,
            currency: "INR",
            payerId: payerId,
            groupId: groupId,
            category: category,
            expenseDate: expenseDate,
            splits: splits
        )

        isSubmitting = true
        errorMessage = nil

        do {
            _ = try await ledgerService.createExpense(payload)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isSubmitting = false
            await onCreated?()
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }

    /// Distributes paise accurately so split sums always match `amount` to the penny.
    static func calculateEqualSplits(
        amount: Decimal,
        participantIDs: [UUID],
        payerId: UUID
    ) -> [ExpenseSplitCreate] {
        let totalPaise = NSDecimalNumber(decimal: amount * 100).rounding(accordingToBehavior: nil).intValue
        let count = participantIDs.count
        let baseShare = totalPaise / count
        var remainder = totalPaise % count

        // Give leftover 1-paise coins deterministically (payer last, others first, or first N)
        let ordered = participantIDs.sorted { lhs, rhs in
            if lhs == payerId { return true }
            if rhs == payerId { return false }
            return lhs.uuidString < rhs.uuidString
        }

        return ordered.map { uid in
            let extra = remainder > 0 ? 1 : 0
            if remainder > 0 { remainder -= 1 }
            let owed = Decimal(baseShare + extra) / Decimal(100)
            return ExpenseSplitCreate(
                userId: uid,
                owedAmount: owed,
                splitType: "EQUAL",
                splitValue: nil
            )
        }
    }
}

struct ManualExpenseFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ManualExpenseFormViewModel

    private let categories = [
        "general", "food", "fuel", "groceries", "travel", "shopping", "bills", "entertainment"
    ]

    var body: some View {
        NavigationStack {
            Form {
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.owedNegative)
                    }
                }

                if let groupName = viewModel.groupName {
                    Section {
                        Label("Group: \(groupName)", systemImage: "person.3.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.brand)
                    }
                }

                Section("Expense Details") {
                    TextField("Description (e.g. Dinner, Cab, Groceries)", text: $viewModel.description)

                    HStack {
                        Text("₹")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $viewModel.amountText)
                            .font(.headline)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Paid By", selection: $viewModel.payerId) {
                        ForEach(viewModel.availableParticipants) { person in
                            Text(person.isCurrentUser ? "\(person.name) (You)" : person.name)
                                .tag(person.id)
                        }
                    }

                    Picker("Category", selection: $viewModel.category) {
                        ForEach(categories, id: \.self) { cat in
                            Label(cat.capitalized, systemImage: AppTheme.categoryIcon(for: cat))
                                .tag(cat)
                        }
                    }

                    DatePicker("Date", selection: $viewModel.expenseDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    Picker("Split Method", selection: $viewModel.splitMode) {
                        ForEach(ManualSplitMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if viewModel.splitMode == .equal {
                    Section {
                        ForEach(viewModel.availableParticipants) { person in
                            let isSelected = viewModel.selectedParticipantIDs.contains(person.id)
                            Button {
                                viewModel.toggleParticipant(person.id)
                            } label: {
                                HStack {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSelected ? AppTheme.brand : .secondary)
                                    Text(person.isCurrentUser ? "\(person.name) (You)" : person.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if isSelected, let total = viewModel.parsedAmount, total > 0 {
                                        let share = total / Decimal(max(1, viewModel.selectedParticipantIDs.count))
                                        Text(CurrencyFormatter.formatINR(share))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Split Between (\(viewModel.selectedParticipantIDs.count))")
                    }
                } else {
                    Section {
                        ForEach(viewModel.availableParticipants) { person in
                            HStack {
                                Text(person.isCurrentUser ? "\(person.name) (You)" : person.name)
                                Spacer()
                                Text("₹")
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: exactBinding(for: person.id))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 96)
                            }
                        }
                    } header: {
                        Text("Exact Split Amounts")
                    } footer: {
                        let rem = viewModel.exactRemaining
                        if rem == 0, (viewModel.parsedAmount ?? 0) > 0 {
                            Text("Splits match total exactly.")
                                .foregroundStyle(AppTheme.owedPositive)
                        } else {
                            Text("Remaining to allocate: \(CurrencyFormatter.formatINR(rem))")
                                .foregroundStyle(rem == 0 ? Color.secondary : AppTheme.owedNegative)
                        }
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let ok = await viewModel.submit()
                            if ok { dismiss() }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSubmitting)
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView("Saving expense...")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func exactBinding(for userId: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.exactAmountsByUserID[userId] ?? "" },
            set: { viewModel.exactAmountsByUserID[userId] = $0 }
        )
    }
}
