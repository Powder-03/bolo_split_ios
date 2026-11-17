//
//  AddFriendSheet.swift
//  BoloSplit
//
//  Form sheet to register a friend by email or phone with optional voice aliases.
//

import SwiftUI

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: FriendsTabViewModel

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var nickname = ""
    @State private var aliasesText = ""
    @State private var localError: String?

    private var hasContactIdentifier: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

                Section("Friend Details") {
                    TextField("Name (e.g. Sahaj)", text: $name)
                        .textContentType(.name)

                    TextField("Email (e.g. sahaj@gmail.com)", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)

                    TextField("Phone (e.g. +919876543210)", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                Section {
                    TextField("Nickname (optional, e.g. Bro)", text: $nickname)
                    TextField("Spoken aliases (comma separated)", text: $aliasesText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Voice Recognition (Optional)")
                } footer: {
                    Text("Add phonetic spellings (e.g. \"sahej, bhai\") so BoloSplit AI recognizes them even if speech-to-text spells their name differently.")
                }

                Section {
                    Text("At least an email or phone number is required. Even if your friend hasn't joined BoloSplit yet, you can start splitting with them immediately.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await submit() }
                    }
                    .disabled(!hasContactIdentifier || viewModel.isSavingFriend)
                }
            }
            .overlay {
                if viewModel.isSavingFriend {
                    ProgressView("Adding friend...")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func submit() async {
        localError = nil
        let result = await viewModel.addFriend(
            name: name,
            email: email,
            phone: phone,
            nickname: nickname,
            aliasesText: aliasesText
        )
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            localError = error.localizedDescription
        }
    }
}
