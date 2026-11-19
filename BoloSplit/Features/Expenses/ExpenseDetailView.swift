//
//  ExpenseDetailView.swift
//  BoloSplit
//
//  Detailed expense view displaying split breakdown with share bars, Edit sheet (PATCH), and Delete action.
//

import SwiftUI
import UIKit

struct ExpenseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ExpenseDetailViewModel

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.expense == nil {
                SkeletonLoadingView(showBannerCard: true, rowCount: 3)
            } else {
                List {
                    if let error = viewModel.errorMessage {
                        Section {
                            ErrorBanner(message: error) {
                                Task { await viewModel.loadDetail() }
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }

                    if let expense = viewModel.expense {
                        Section {
                            ExpenseDetailHeaderCard(expense: expense)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)

                        Section("Split Breakdown") {
                            if expense.splits.isEmpty {
                                Text("No individual splits recorded.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(expense.splits.enumerated()), id: \.element.id) { index, split in
                                    let name = viewModel.displayName(for: split.userId)
                                    let ratio = shareRatio(owed: split.owedAmount, total: expense.amount)
                                    VStack(spacing: 8) {
                                        HStack(spacing: 12) {
                                            UserAvatarBadge(name: name, size: 36)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(name)
                                                    .font(.body.weight(.medium))
                                                Text(split.splitType.capitalized)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text(CurrencyFormatter.formatINR(split.owedAmount))
                                                    .font(.subheadline.weight(.semibold))
                                                    .contentTransition(.numericText())
                                                Text("\(Int((ratio * 100).rounded()))%")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color.secondary.opacity(0.12))
                                                Capsule()
                                                    .fill(AppTheme.avatarColor(for: name).gradient)
                                                    .frame(width: max(6, geo.size.width * ratio))
                                            }
                                        }
                                        .frame(height: 4)
                                        .animation(AppMotion.gentle, value: ratio)
                                    }
                                    .padding(.vertical, 3)
                                    .staggeredEntrance(index: index)
                                }
                            }
                        }

                        Section {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Delete Expense", systemImage: "trash")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                            }
                            .disabled(viewModel.isDeleting)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .animation(AppMotion.snappy, value: viewModel.expense)
            }
        }
        .navigationTitle("Expense Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.expense != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        showEditSheet = true
                    }
                }
            }
        }
        .refreshable {
            await viewModel.loadDetail()
        }
        .task {
            await viewModel.loadDetail()
        }
        .sheet(isPresented: $showEditSheet) {
            if let expense = viewModel.expense {
                EditExpenseSheet(expense: expense, viewModel: viewModel)
            }
        }
        .confirmationDialog(
            "Delete this expense?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Expense", role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    let deleted = await viewModel.deleteExpense()
                    if deleted { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the expense and recalculate all affected balances.")
        }
    }

    private func shareRatio(owed: Decimal, total: Decimal) -> Double {
        let totalDouble = NSDecimalNumber(decimal: total).doubleValue
        let owedDouble = NSDecimalNumber(decimal: owed).doubleValue
        guard totalDouble > 0 else { return 0 }
        return min(max(owedDouble / totalDouble, 0), 1)
    }
}

private struct ExpenseDetailHeaderCard: View {
    let expense: ExpenseRead

    private var catColor: Color {
        AppTheme.categoryColor(for: expense.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(catColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: AppTheme.categoryIcon(for: expense.category))
                            .font(.title2)
                            .foregroundStyle(catColor)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.description)
                        .font(.title3.bold())
                    Text((expense.category ?? "general").capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(catColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(catColor.opacity(0.12), in: Capsule())
                }

                Spacer()
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Amount")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatINR(expense.amount))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Paid by \(expense.payerName ?? "Member")")
                        .font(.subheadline.weight(.medium))
                    Text(expense.expenseDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .tintedCardSurface(tint: catColor, cornerRadius: 16)
    }
}

private struct EditExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ExpenseDetailViewModel

    @State private var description: String
    @State private var amountText: String
    @State private var category: String
    @State private var date: Date

    private let categories = [
        "general", "food", "fuel", "groceries", "travel", "shopping", "bills", "entertainment"
    ]

    init(expense: ExpenseRead, viewModel: ExpenseDetailViewModel) {
        self.viewModel = viewModel
        _description = State(initialValue: expense.description)
        let numeric = NSDecimalNumber(decimal: expense.amount).doubleValue
        _amountText = State(initialValue: String(format: "%.2f", numeric))
        _category = State(initialValue: (expense.category ?? "general").lowercased())
        _date = State(initialValue: expense.expenseDate)
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isValid: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (parsedAmount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Update Expense") {
                    TextField("Description", text: $description)

                    HStack {
                        Text("₹")
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Label(cat.capitalized, systemImage: AppTheme.categoryIcon(for: cat))
                                .tag(cat)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    Text("Changing the amount automatically rebalances equal splits across participants.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = parsedAmount else { return }
                        Task {
                            let ok = await viewModel.updateExpense(
                                description: description,
                                amount: amount,
                                category: category,
                                date: date
                            )
                            if ok { dismiss() }
                        }
                    }
                    .disabled(!isValid || viewModel.isSaving)
                }
            }
        }
    }
}
