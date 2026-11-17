//
//  SettleUpSheet.swift
//  BoloSplit
//
//  Splitwise-style Settle Up payment form supporting UPI/GPay/PhonePe/Cash & UTR ref.
//

import SwiftUI

struct SettleUpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SettleUpViewModel

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

                Section {
                    HStack(spacing: 12) {
                        Label("You", systemImage: "person.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.brand)

                        Image(systemName: "arrow.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Label(viewModel.friendName, systemImage: "person.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.owedPositive)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)

                    HStack {
                        Text("₹")
                            .font(.title2.bold())
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $viewModel.amountText)
                            .font(.title2.bold())
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Payment Amount")
                } footer: {
                    if viewModel.netBalance < 0 {
                        Text("You currently owe \(viewModel.friendName) \(CurrencyFormatter.formatINR(abs(viewModel.netBalance))).")
                    } else if viewModel.netBalance > 0 {
                        Text("Note: \(viewModel.friendName) currently owes you \(CurrencyFormatter.formatINR(viewModel.netBalance)). Recording this will log a payment from you to \(viewModel.friendName).")
                    }
                }

                Section("Payment Method & Details") {
                    Picker("Paid Via", selection: $viewModel.paymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }

                    TextField("UTR / UPI Reference (optional)", text: $viewModel.transactionReference)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Note (optional)", text: $viewModel.notes)

                    DatePicker("Date", selection: $viewModel.settlementDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let ok = await viewModel.submitSettlement()
                            if ok { dismiss() }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSubmitting)
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView("Recording payment...")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
}
