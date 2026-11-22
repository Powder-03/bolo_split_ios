//
//  SelfTabView.swift
//  BoloSplit
//
//  Personal / Solo expenses tab showing monthly total, category breakdown bar,
//  gliding filter chips, and solo transactions.
//

import SwiftUI
import UIKit

struct SelfTabView: View {
    @Bindable var viewModel: SelfTabViewModel
    @State private var showAddSheet = false
    @State private var editingExpense: SelfExpenseRead?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.summary == nil {
                    SkeletonLoadingView(showBannerCard: true, rowCount: 5)
                } else {
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
                                    subtitle: "Tap + or speak to Bolo without mentioning a friend or group (e.g. \"500 petrol\") to track personal spending.",
                                    actionTitle: viewModel.selectedCategory == nil ? "Add Solo Expense" : nil
                                ) {
                                    showAddSheet = true
                                }
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            Section(sectionTitle) {
                                ForEach(Array(viewModel.expenses.enumerated()), id: \.element.id) { index, expense in
                                    Button {
                                        editingExpense = expense
                                    } label: {
                                        SelfExpenseRow(expense: expense)
                                    }
                                    .buttonStyle(.plain)
                                    .staggeredEntrance(index: index)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                    .animation(AppMotion.snappy, value: viewModel.expenses)
                }
            }
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
            .refreshable {
                await viewModel.loadSelfExpenses()
            }
            .task {
                await viewModel.loadIfNeeded()
            }
            .sheet(isPresented: $showAddSheet) {
                AddSelfExpenseSheet(viewModel: viewModel)
            }
            .sheet(item: $editingExpense) { expense in
                EditSelfExpenseSheet(viewModel: viewModel, expense: expense)
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

    private var totalCategorySum: Double {
        summary.categories.reduce(0) { partial, stat in
            partial + max(0, NSDecimalNumber(decimal: stat.totalAmount).doubleValue)
        }
    }

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
                        .contentTransition(.numericText())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Entries")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(summary.totalCount)")
                        .font(.title3.weight(.bold))
                        .contentTransition(.numericText())
                }
            }

            if totalCategorySum > 0 && !summary.categories.isEmpty {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(summary.categories.prefix(5)) { stat in
                            let val = max(0, NSDecimalNumber(decimal: stat.totalAmount).doubleValue)
                            let fraction = val / totalCategorySum
                            if fraction > 0.01 {
                                Capsule()
                                    .fill(AppTheme.categoryColor(for: stat.category).gradient)
                                    .frame(width: max(6, geo.size.width * fraction - 2))
                            }
                        }
                    }
                }
                .frame(height: 6)
                .animation(AppMotion.gentle, value: summary.categories)
            }

            Divider()

            HStack {
                Label("All-time solo spend", systemImage: "wallet.bifold.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(CurrencyFormatter.formatINR(summary.totalSpending))
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
            }

            Text("Personal expenses don't affect friend or group balances.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .tintedCardSurface(tint: AppTheme.brand, cornerRadius: 16)
    }
}

// MARK: - Horizontal Category Filter Chips

private struct CategoryFilterStrip: View {
    let categories: [SelfCategoryStat]
    let selectedCategory: String?
    let onSelect: (String?) -> Void
    @Namespace private var chipNamespace

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
                        .foregroundStyle(selectedCategory == nil ? .white : .primary)
                        .background {
                            if selectedCategory == nil {
                                Capsule()
                                    .fill(AppTheme.brandGradient)
                                    .matchedGeometryEffect(id: "selfCategoryPill", in: chipNamespace)
                            } else {
                                Capsule()
                                    .fill(Color(.secondarySystemGroupedBackground))
                            }
                        }
                }
                .buttonStyle(BoloPressButtonStyle(scale: 0.95))

                ForEach(categories) { stat in
                    let isSelected = selectedCategory == stat.category.lowercased()
                    Button {
                        onSelect(stat.category)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: AppTheme.categoryIcon(for: stat.category))
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .white : AppTheme.categoryColor(for: stat.category))
                            Text(stat.category.capitalized)
                                .font(.caption.weight(.semibold))
                            Text(CurrencyFormatter.formatINR(stat.totalAmount))
                                .font(.caption2)
                                .opacity(0.85)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(AppTheme.brandGradient)
                                    .matchedGeometryEffect(id: "selfCategoryPill", in: chipNamespace)
                            } else {
                                Capsule()
                                    .fill(Color(.secondarySystemGroupedBackground))
                            }
                        }
                    }
                    .buttonStyle(BoloPressButtonStyle(scale: 0.95))
                }
            }
            .padding(.horizontal, 2)
            .animation(AppMotion.snappy, value: selectedCategory)
        }
        .sensoryFeedback(.selection, trigger: selectedCategory)
    }
}

// MARK: - Solo Expense Row

private struct SelfExpenseRow: View {
    let expense: SelfExpenseRead

    private var catColor: Color {
        AppTheme.categoryColor(for: expense.category)
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(catColor.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: AppTheme.categoryIcon(for: expense.category))
                        .foregroundStyle(catColor)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.description)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text((expense.category ?? "general").capitalized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(catColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(catColor.opacity(0.12), in: Capsule())

                    Text(expense.expenseDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(CurrencyFormatter.formatINR(expense.amount))
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
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

                    DatePicker("Date", selection: $date, displayedComponents: [.date])
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
                            if ok {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!isValid || viewModel.isSubmitting)
                }
            }
        }
    }
}

// MARK: - Edit Solo Expense Sheet

private struct EditSelfExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SelfTabViewModel
    let expense: SelfExpenseRead

    @State private var description: String
    @State private var amountText: String
    @State private var category: String
    @State private var date: Date

    private let categoryOptions = [
        "general", "food", "fuel", "groceries", "travel", "shopping", "bills", "entertainment"
    ]

    init(viewModel: SelfTabViewModel, expense: SelfExpenseRead) {
        self.viewModel = viewModel
        self.expense = expense
        _description = State(initialValue: expense.description)
        _amountText = State(initialValue: NSDecimalNumber(decimal: expense.amount).stringValue)
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
                Section("Expense Details") {
                    TextField("Description", text: $description)

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

                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                Section {
                    Button(role: .destructive) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task {
                            await viewModel.deleteExpense(expense)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Solo Expense", systemImage: "trash")
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
            .navigationTitle("Edit Solo Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = parsedAmount else { return }
                        Task {
                            let ok = await viewModel.updateSelfExpense(
                                id: expense.id,
                                description: description,
                                amount: amount,
                                category: category,
                                date: date
                            )
                            if ok {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!isValid || viewModel.isSubmitting)
                }
            }
        }
    }
}
