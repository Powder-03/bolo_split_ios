//
//  SelfTabView.swift
//  BoloSplit
//
//  Personal / Solo expenses tab showing monthly total, category stats, and solo transactions.
//

import SwiftUI

struct SelfTabView: View {
    @Bindable var viewModel: SelfTabViewModel
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                if let error = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: error) {
                            Task { await viewModel.loadSelfExpenses() }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if let summary = viewModel.summary {
                    Section {
                        SelfSummaryBannerCard(summary: summary)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    if !summary.categories.isEmpty {
                        Section {
                            CategoryFilterStrip(
                                categories: summary.categories,
                                selectedCategory: viewModel.selectedCategory
                            ) { category in
                                Task { await viewModel.selectCategory(category) }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }

                if viewModel.expenses.isEmpty && !viewModel.isLoading {
                    Section {
                        EmptyStateView(
                            systemImage: "person.fill",
                            title: viewModel.selectedCategory == nil
                                ? "No solo expenses yet"
                                : "No expenses in \(viewModel.selectedCategory?.capitalized ?? "category")",
                            subtitle: "Tap + or speak to Bolo without mentioning a friend or group (e.g. \"500 petrol\") to track personal spending."
                        )
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section(sectionTitle) {
                        ForEach(viewModel.expenses) { expense in
                            SelfExpenseRow(expense: expense)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteExpense(expense) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Self")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Add solo expense")
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.summary == nil {
                    ProgressView("Loading personal expenses...")
                }
            }
            .refreshable {
                await viewModel.loadSelfExpenses()
            }
            .task {
                await viewModel.loadIfNeeded()
            }
            .sheet(isPresented: $showAddSheet) {
                AddSelfExpenseSheet(viewModel: viewModel)
            }
        }
    }

    private var sectionTitle: String {
        if let cat = viewModel.selectedCategory {
            return "\(cat.capitalized) Expenses (\(viewModel.summary?.totalCount ?? viewModel.expenses.count))"
        }
        return "Personal Expenses"
    }
}

// MARK: - Top Summary Banner

private struct SelfSummaryBannerCard: View {
    let summary: SelfExpensesSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Month (Solo)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatINR(summary.thisMonthSpending))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.brand)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Entries")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(summary.totalCount)")
                        .font(.title3.weight(.bold))
                }
            }

            Divider()

            HStack {
                Label("All-time solo spend", systemImage: "wallet.bifold.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(CurrencyFormatter.formatINR(summary.totalSpending))
                    .font(.subheadline.weight(.semibold))
            }

            Text("Personal expenses don't affect friend or group balances.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Horizontal Category Filter Chips

private struct CategoryFilterStrip: View {
    let categories: [SelfCategoryStat]
    let selectedCategory: String?
    let onSelect: (String?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    onSelect(nil)
                } label: {
                    Text("All")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == nil ? AppTheme.brand : Color(.secondarySystemGroupedBackground),
                            in: Capsule()
                        )
                        .foregroundStyle(selectedCategory == nil ? .white : .primary)
                }
                .buttonStyle(.plain)

                ForEach(categories) { stat in
                    let isSelected = selectedCategory == stat.category.lowercased()
                    Button {
                        onSelect(stat.category)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: AppTheme.categoryIcon(for: stat.category))
                                .font(.caption2)
                            Text(stat.category.capitalized)
                                .font(.caption.weight(.semibold))
                            Text(CurrencyFormatter.formatINR(stat.totalAmount))
                                .font(.caption2)
                                .opacity(0.85)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? AppTheme.brand : Color(.secondarySystemGroupedBackground),
                            in: Capsule()
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Solo Expense Row

private struct SelfExpenseRow: View {
    let expense: ExpenseRead

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.brand.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: AppTheme.categoryIcon(for: expense.category))
                        .foregroundStyle(AppTheme.brand)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.description)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text((expense.category ?? "general").capitalized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.brand.opacity(0.1), in: Capsule())

                    Text(expense.expenseDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(CurrencyFormatter.formatINR(expense.amount))
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Solo Expense Sheet

private struct AddSelfExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SelfTabViewModel

    @State private var description = ""
    @State private var amountText = ""
    @State private var category = "general"
    @State private var date = Date()

    private let categoryOptions = [
        "general", "food", "fuel", "groceries", "travel", "shopping", "bills", "entertainment"
    ]

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
                Section("Expense Details") {
                    TextField("Description (e.g. Petrol, Coffee)", text: $description)

                    HStack {
                        Text("₹")
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Category", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { cat in
                            Label(cat.capitalized, systemImage: AppTheme.categoryIcon(for: cat))
                                .tag(cat)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    Text("Saved 100% under Self — no friends or groups will be charged.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Solo Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = parsedAmount else { return }
                        Task {
                            let ok = await viewModel.addSelfExpense(
                                description: description,
                                amount: amount,
                                category: category,
                                date: date
                            )
                            if ok { dismiss() }
                        }
                    }
                    .disabled(!isValid || viewModel.isSubmitting)
                }
            }
        }
    }
}
