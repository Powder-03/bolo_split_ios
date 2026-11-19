//
//  GroupDetailView.swift
//  BoloSplit
//
//  Group dashboard with animated invite code copy pill, members roster,
//  group balances, contextual Bolo mic + manual expense CTA, and chronological timeline.
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
        Group {
            if viewModel.isLoading && viewModel.detail == nil {
                SkeletonLoadingView(showBannerCard: true, rowCount: 5)
            } else {
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
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                withAnimation(AppMotion.snappy) {
                                    copiedInvite = true
                                }
                                Task {
                                    try? await Task.sleep(for: .seconds(2))
                                    withAnimation(AppMotion.snappy) {
                                        copiedInvite = false
                                    }
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
                            HStack(spacing: 12) {
                                ForEach(Array(viewModel.members.enumerated()), id: \.element.id) { index, member in
                                    VStack(spacing: 5) {
                                        UserAvatarBadge(name: member.name, size: 44)

                                        Text(member.name)
                                            .font(.caption2.weight(.medium))
                                            .lineLimit(1)
                                            .frame(maxWidth: 64)
                                    }
                                    .staggeredEntrance(index: index)
                                }

                                Button {
                                    showAddMember = true
                                } label: {
                                    VStack(spacing: 5) {
                                        Circle()
                                            .strokeBorder(AppTheme.brand, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                            .frame(width: 44, height: 44)
                                            .overlay {
                                                Image(systemName: "plus")
                                                    .foregroundStyle(AppTheme.brand)
                                            }
                                        Text("Add")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(AppTheme.brand)
                                    }
                                }
                                .buttonStyle(BoloPressButtonStyle(scale: 0.92, haptic: .light))
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
                                HStack(spacing: 10) {
                                    UserAvatarBadge(
                                        name: bal.userName,
                                        size: 32,
                                        ringColor: bal.netBalance == 0 ? nil : AppTheme.balanceColor(for: bal.netBalance)
                                    )

                                    Text(bal.userName)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    if bal.netBalance > 0 {
                                        Text("owes you \(CurrencyFormatter.formatINR(bal.netBalance))")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.owedPositive)
                                            .contentTransition(.numericText())
                                    } else if bal.netBalance < 0 {
                                        Text("you owe \(CurrencyFormatter.formatINR(abs(bal.netBalance)))")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.owedNegative)
                                            .contentTransition(.numericText())
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
                                subtitle: "Tap Bolo in Group or Add Manual to split bills with \(viewModel.group.name)."
                            )
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        Section("Group Timeline") {
                            ForEach(Array(viewModel.timeline.enumerated()), id: \.element.id) { index, item in
                                if item.isSettlement {
                                    GroupTimelineRow(item: item)
                                        .staggeredEntrance(index: index)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                                    .staggeredEntrance(index: index)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                .animation(AppMotion.snappy, value: viewModel.timeline)
            }
        }
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
                        .contentTransition(.numericText())
                }

                Spacer()

                Button(action: onCopyInvite) {
                    HStack(spacing: 6) {
                        Text(copiedInvite ? "Copied!" : inviteCode)
                            .font(.caption.monospaced().weight(.bold))
                        Image(systemName: copiedInvite ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .foregroundStyle(copiedInvite ? AppTheme.owedPositive : AppTheme.brand)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        (copiedInvite ? AppTheme.owedPositive : AppTheme.brand).opacity(0.13),
                        in: Capsule()
                    )
                }
                .buttonStyle(BoloPressButtonStyle(scale: 0.94))
            }

            HStack(spacing: 10) {
                Button(action: onSpeakInGroup) {
                    Label("Bolo in Group", systemImage: "mic.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: AppTheme.brand.opacity(0.25), radius: 6, y: 3)
                }
                .buttonStyle(BoloPressButtonStyle(haptic: .medium))

                Button(action: onAddExpense) {
                    Label("Add Manual", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.brand.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(BoloPressButtonStyle(haptic: .light))
                .disabled(memberCount == 0)
            }
        }
        .padding(16)
        .tintedCardSurface(tint: AppTheme.brand, cornerRadius: 16)
    }
}

private struct GroupTimelineRow: View {
    let item: ActivityTimelineItem

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill((item.isSettlement ? AppTheme.owedPositive : AppTheme.brand).opacity(0.14))
                .frame(width: 42, height: 42)
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
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.balanceColor(for: item.yourNetImpact))
                    Text(CurrencyFormatter.formatINR(abs(item.yourNetImpact)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.balanceColor(for: item.yourNetImpact))
                        .contentTransition(.numericText())
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        case .failure(let error):
            localError = error.localizedDescription
        }
    }
}
