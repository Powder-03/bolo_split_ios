//
//  CreateOrJoinGroupSheet.swift
//  BoloSplit
//
//  Sheet allowing users to create a new group or join an existing group via 6-char invite code.
//

import SwiftUI

enum GroupSheetMode: String, CaseIterable, Identifiable {
    case create = "Create Group"
    case join = "Join by Code"

    var id: String { rawValue }
}

struct CreateOrJoinGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: GroupsTabViewModel

    @State private var mode: GroupSheetMode = .create
    @State private var groupName = ""
    @State private var inviteCode = ""
    @State private var localError: String?

    private var isValid: Bool {
        switch mode {
        case .create:
            return !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .join:
            return !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Action", selection: $mode) {
                        ForEach(GroupSheetMode.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

                if let localError {
                    Section {
                        Text(localError)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.owedNegative)
                    }
                }

                if mode == .create {
                    Section {
                        TextField("Group name (e.g. Goa Trip, Flat 302)", text: $groupName)
                    } header: {
                        Text("New Group")
                    } footer: {
                        Text("A 6-character invite code is generated automatically so friends can join or you can add members directly.")
                    }
                } else {
                    Section {
                        TextField("6-character code (e.g. A1B2C3)", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Invite Code")
                    } footer: {
                        Text("Ask any group member for the invite code shown in their Group Details screen.")
                    }
                }
            }
            .animation(AppMotion.snappy, value: mode)
            .navigationTitle(mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .create ? "Create" : "Join") {
                        Task { await submit() }
                    }
                    .disabled(!isValid || viewModel.isSubmitting)
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView(mode == .create ? "Creating group..." : "Joining group...")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func submit() async {
        localError = nil
        let result: Result<GroupRead, Error>
        switch mode {
        case .create:
            result = await viewModel.createGroup(name: groupName)
        case .join:
            result = await viewModel.joinGroup(inviteCode: inviteCode)
        }

        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            localError = error.localizedDescription
        }
    }
}
