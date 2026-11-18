//
//  ExpenseDetailView.swift
//  BoloSplit
//
//  Detailed expense view displaying split breakdown, Edit sheet (PATCH), and Delete action.
//

import SwiftUI

struct ExpenseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ExpenseDetailViewModel

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
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
                        ForEach(expense.splits) { split in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(AppTheme.brand.opacity(0.14))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        Text(String(viewModel.displayName(for: split.userId).prefix(1)).uppercased())
                                            .font(.subheadline.bold())
                                            .foregroundStyle(AppTheme.brand)
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.displayName(for: split.userId))
                                        .font(.body.weight(.medium))
                                    Text(split.splitType.capitalized)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(CurrencyFormatter.formatINR(split.owedAmount))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.vertical, 2)
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
        .overlay {
            if viewModel.isLoading && viewModel.expense == nil {
                ProgressView("Loading expense...")
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
}

private struct ExpenseDetailHeaderCard: View {
    let expense: ExpenseRead

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.brand.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: AppTheme.categoryIcon(for: expense.category))
                            .font(.title2)
                            .foregroundStyle(AppTheme.brand)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.description)
                        .font(.title3.bold())
                    Text((expense.category ?? "general").capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.brand.opacity(0.12), in: Capsule())
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
