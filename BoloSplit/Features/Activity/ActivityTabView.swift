//
//  ActivityTabView.swift
//  BoloSplit
//
//  Splitwise-style Activity tab with filter pills, search, date grouping, and smooth animations.
//

import SwiftUI
import UIKit

private enum ActivityFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case expenses = "Expenses"
    case settlements = "Settlements"
    case personal = "Personal"

    var id: String { rawValue }
}

private struct ActivityDateSection: Identifiable, Equatable {
    let title: String
    let entries: [ActivityFeedEntry]

    var id: String { title }
}

struct ActivityTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var viewModel: ActivityTabViewModel

    @State private var filter: ActivityFilter = .all
    @State private var searchText = ""
    @Namespace private var filterNamespace

    private var filteredEntries: [ActivityFeedEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return viewModel.entries.filter { entry in
            let matchesFilter: Bool = {
                switch filter {
                case .all: return true
                case .expenses:
                    if case .expense = entry.kind { return true }
                    return false
                case .settlements:
                    return entry.isSettlement
                case .personal:
                    if case .expense(let exp) = entry.kind {
                        return exp.groupId == nil && exp.splits.count <= 1
                    }
                    return false
                }
            }()

            guard !query.isEmpty else { return matchesFilter }
            return matchesFilter && (
                entry.title.localizedCaseInsensitiveContains(query)
                    || entry.subtitle.localizedCaseInsensitiveContains(query)
                    || (entry.category?.localizedCaseInsensitiveContains(query) ?? false)
            )
        }
    }

    private var groupedSections: [ActivityDateSection] {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        var today: [ActivityFeedEntry] = []
        var yesterday: [ActivityFeedEntry] = []
        var thisWeek: [ActivityFeedEntry] = []
        var earlier: [ActivityFeedEntry] = []

        for entry in filteredEntries {
            if calendar.isDateInToday(entry.date) {
                today.append(entry)
            } else if calendar.isDateInYesterday(entry.date) {
                yesterday.append(entry)
            } else if entry.date >= weekAgo {
                thisWeek.append(entry)
            } else {
                earlier.append(entry)
            }
        }

        var result: [ActivityDateSection] = []
        if !today.isEmpty { result.append(ActivityDateSection(title: "Today", entries: today)) }
        if !yesterday.isEmpty { result.append(ActivityDateSection(title: "Yesterday", entries: yesterday)) }
        if !thisWeek.isEmpty { result.append(ActivityDateSection(title: "This Week", entries: thisWeek)) }
        if !earlier.isEmpty { result.append(ActivityDateSection(title: "Earlier", entries: earlier)) }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    SkeletonLoadingView(showBannerCard: false, rowCount: 6)
                } else {
                    List {
                        if let error = viewModel.errorMessage {
                            Section {
                                ErrorBanner(message: error) {
                                    Task { await viewModel.loadActivity() }
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

                        if !viewModel.entries.isEmpty {
                            Section {
                                filterChipStrip
                            }
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                            .listRowBackground(Color.clear)
                        }

                        if viewModel.entries.isEmpty && !viewModel.isLoading {
                            Section {
                                EmptyStateView(
                                    systemImage: "clock.arrow.circlepath",
                                    title: "No activity yet",
                                    subtitle: "Your voice expenses and settlements will appear here in chronological order."
                                )
                            }
                            .listRowBackground(Color.clear)
                        } else if filteredEntries.isEmpty {
                            Section {
                                EmptyStateView(
                                    systemImage: "magnifyingglass",
                                    title: "No matching activity",
                                    subtitle: "Try clearing your search or switching the filter."
                                )
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(groupedSections) { section in
                                Section(section.title) {
                                    ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                                        rowView(for: entry, index: index)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .animation(AppMotion.snappy, value: groupedSections)
                }
            }
            .navigationTitle("Activity")
            .searchable(text: $searchText, prompt: "Search expenses or settlements")
            .refreshable {
                await viewModel.loadActivity()
            }
            .task {
                await viewModel.loadIfNeeded()
            }
        }
    }

    @ViewBuilder
    private func rowView(for entry: ActivityFeedEntry, index: Int) -> some View {
        switch entry.kind {
        case .expense(let expense):
            NavigationLink {
                ExpenseDetailView(
                    viewModel: environment.makeExpenseDetailViewModel(
                        expenseId: expense.id,
                        initialExpense: expense
                    )
                )
            } label: {
                ActivityRow(entry: entry)
            }
            .staggeredEntrance(index: index)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        await viewModel.deleteEntry(entry)
                        await environment.refreshAllFeeds()
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

        case .settlement:
            ActivityRow(entry: entry)
                .staggeredEntrance(index: index)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task {
                            await viewModel.deleteEntry(entry)
                            await environment.refreshAllFeeds()
                        }
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                }
        }
    }

    private var filterChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ActivityFilter.allCases) { item in
                    let isSelected = filter == item
                    Button {
                        withAnimation(AppMotion.snappy) {
                            filter = item
                        }
                    } label: {
                        Text(item.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(isSelected ? .white : .primary)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(AppTheme.brandGradient)
                                        .matchedGeometryEffect(id: "activityFilterPill", in: filterNamespace)
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
        }
        .sensoryFeedback(.selection, trigger: filter)
    }
}

private struct ActivityRow: View {
    let entry: ActivityFeedEntry

    private var iconColor: Color {
        entry.isSettlement ? AppTheme.owedPositive : AppTheme.categoryColor(for: entry.category)
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(iconColor.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: entry.isSettlement
                          ? "checkmark.seal.fill"
                          : AppTheme.categoryIcon(for: entry.category))
                        .foregroundStyle(iconColor)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(CurrencyFormatter.formatINR(entry.amount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(entry.isSettlement ? AppTheme.owedPositive : .primary)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 4)
    }
}
