//
//  GroupDetailView.swift
//  BoloSplit
//
//  Group dashboard with copyable invite code, members roster, group balances,
//  contextual Bolo mic + manual expense CTA, and chronological group timeline.
//

import SwiftUI
import UIKit

struct GroupDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var viewModel: GroupDetailViewModel

    @State private var showAddMember = false
    @State private var showAddExpense = false
    @State private var copiedInvite = false

    private var groupParticipants: [ExpenseParticipant] {
        let callerEmail = environment.authViewModel.currentUser?.email.lowercased()
        return viewModel.members.map { member in
            let isCaller = callerEmail != nil && member.email.lowercased() == callerEmail
            return ExpenseParticipant(
                id: member.userId,
                name: member.name,
                isCurrentUser: isCaller
            )
        }
    }

    private var knownNamesMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: viewModel.members.map { ($0.userId, $0.name) })
    }

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    ErrorBanner(message: error) {
                        Task { await viewModel.loadGroupData() }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                GroupHeaderSummaryCard(
                    groupName: viewModel.group.name,
                    inviteCode: viewModel.inviteCode,
                    totalSpending: viewModel.totalSpending,
                    memberCount: viewModel.members.count,
                    copiedInvite: copiedInvite,
                    onCopyInvite: {
                        UIPasteboard.general.string = viewModel.inviteCode
                        copiedInvite = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copiedInvite = false
                        }
                    },
                    onAddExpense: { showAddExpense = true },
                    onSpeakInGroup: {
                        environment.openVoiceOverlay(
                            groupId: viewModel.group.id,
                            groupName: viewModel.group.name
                        )
                    }
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Members Roster
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.members) { member in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(AppTheme.brand.opacity(0.15))
                                    .frame(width: 42, height: 42)
                                    .overlay {
                                        Text(String(member.name.prefix(1)).uppercased())
                                            .font(.subheadline.bold())
                                            .foregroundStyle(AppTheme.brand)
                                    }

                                Text(member.name)
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                                    .frame(maxWidth: 64)
                            }
                        }

                        Button {
                            showAddMember = true
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .strokeBorder(AppTheme.brand, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                    .frame(width: 42, height: 42)
                                    .overlay {
                                        Image(systemName: "plus")
                                            .foregroundStyle(AppTheme.brand)
                                    }
                                Text("Add")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.brand)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("Members (\(viewModel.members.count))")
                    Spacer()
                }
            }

            // Group Net Balances
            if let balances = viewModel.groupBalances?.balances, !balances.isEmpty {
                Section("Group Balances") {
                    ForEach(balances) { bal in
                        HStack {
                            Text(bal.userName)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if bal.netBalance > 0 {
                                Text("owes you \(CurrencyFormatter.formatINR(bal.netBalance))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.owedPositive)
                            } else if bal.netBalance < 0 {
                                Text("you owe \(CurrencyFormatter.formatINR(abs(bal.netBalance)))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.owedNegative)
                            } else {
                                Text("settled up")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Group Activity Timeline
            if viewModel.timeline.isEmpty && !viewModel.isLoading {
                Section {
                    EmptyStateView(
                        systemImage: "list.bullet.rectangle.portrait",
                        title: "No group expenses yet",
                        subtitle: "Tap Speak to Bolo or Add Expense to split bills with \(viewModel.group.name)."
                    )
                }
                .listRowBackground(Color.clear)
            } else {
                Section("Group Timeline") {
                    ForEach(viewModel.timeline) { item in
                        if item.isSettlement {
                            GroupTimelineRow(item: item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.undoSettlement(id: item.id) }
                                    } label: {
                                        Label("Undo", systemImage: "arrow.uturn.backward")
                                    }
                                }
                        } else {
                            NavigationLink {
                                ExpenseDetailView(
                                    viewModel: environment.makeExpenseDetailViewModel(
                                        expenseId: item.id,
                                        knownUserNames: knownNamesMap,
                                        onChanged: {
                                            await viewModel.loadGroupData()
                                        }
                                    )
                                )
                            } label: {
                                GroupTimelineRow(item: item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteExpense(id: item.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddExpense = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .disabled(groupParticipants.isEmpty)
                .accessibilityLabel("Add group expense")
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.detail == nil {
                ProgressView("Loading group...")
            }
        }
        .refreshable {
            await viewModel.loadGroupData()
        }
        .task {
            await viewModel.loadGroupData()
        }
        .sheet(isPresented: $showAddMember) {
            AddGroupMemberSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAddExpense) {
            ManualExpenseFormSheet(
                viewModel: environment.makeManualExpenseFormViewModel(
                    groupId: viewModel.group.id,
                    groupName: viewModel.group.name,
                    participants: groupParticipants,
                    onCreated: {
                        await viewModel.loadGroupData()
                    }
                )
            )
        }
    }
}

// MARK: - Subviews

private struct GroupHeaderSummaryCard: View {
    let groupName: String
    let inviteCode: String
    let totalSpending: Decimal
    let memberCount: Int
    let copiedInvite: Bool
    let onCopyInvite: () -> Void
    let onAddExpense: () -> Void
    let onSpeakInGroup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Group Spending")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatINR(totalSpending))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }

                Spacer()

                Button(action: onCopyInvite) {
                    HStack(spacing: 6) {
                        Text(copiedInvite ? "Copied!" : inviteCode)
                            .font(.caption.monospaced().weight(.bold))
                        Image(systemName: copiedInvite ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                    }
                    .foregroundStyle(AppTheme.brand)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.brand.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button(action: onSpeakInGroup) {
                    Label("Bolo in Group", systemImage: "mic.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AppTheme.brand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onAddExpense) {
                    Label("Add Manual", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AppTheme.brand.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(memberCount == 0)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct GroupTimelineRow: View {
    let item: ActivityTimelineItem

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill((item.isSettlement ? AppTheme.owedPositive : AppTheme.brand).opacity(0.14))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: item.isSettlement ? "checkmark.seal.fill" : "receipt.fill")
                        .foregroundStyle(item.isSettlement ? AppTheme.owedPositive : AppTheme.brand)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.description)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text("\(item.payerName) paid \(CurrencyFormatter.formatINR(item.totalAmount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if item.yourNetImpact != 0 {
                    Text(item.yourNetImpact > 0 ? "you lent" : "you owe")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.balanceColor(for: item.yourNetImpact))
                    Text(CurrencyFormatter.formatINR(abs(item.yourNetImpact)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.balanceColor(for: item.yourNetImpact))
                } else {
                    Text(CurrencyFormatter.formatINR(item.totalAmount))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AddGroupMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: GroupDetailViewModel

    @State private var identifier = ""
    @State private var name = ""
    @State private var localError: String?

    private var isValid: Bool {
        !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if let localError {
                    Section {
                        Text(localError)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.owedNegative)
                    }
                }

                Section {
                    TextField("Email or Phone (e.g. sahaj@gmail.com)", text: $identifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Name (optional if new user)", text: $name)
                        .textContentType(.name)
                } header: {
                    Text("Member Info")
                } footer: {
                    Text("Adding a member to this group also links them as a friend so voice expenses work seamlessly.")
                }
            }
            .navigationTitle("Add Group Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await submit() }
                    }
                    .disabled(!isValid || viewModel.isAddingMember)
                }
            }
            .overlay {
                if viewModel.isAddingMember {
                    ProgressView("Adding member...")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func submit() async {
        localError = nil
        let result = await viewModel.addMember(identifier: identifier, name: name)
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            localError = error.localizedDescription
        }
    }
}
