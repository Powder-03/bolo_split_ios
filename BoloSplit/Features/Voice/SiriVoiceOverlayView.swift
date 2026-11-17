//
//  SiriVoiceOverlayView.swift
//  BoloSplit
//
//  Translucent Siri-like floating voice overlay with audio-reactive glowing orb,
//  instant End submission, typed fallback, and compact confirmation cards.
//

import SwiftUI
import UIKit

struct SiriVoiceOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Bindable var viewModel: VoiceViewModel
    @FocusState private var isTextFieldFocused: Bool

    private let quickExamples = [
        "Add 500 petrol split with Sahaj",
        "Maine Rahul ko 250 UPI kar diye",
        "What are my current balances?"
    ]

    var body: some View {
        VStack(spacing: 20) {
            headerBar

            Spacer(minLength: 4)

            contentBody

            Spacer(minLength: 4)

            bottomActions
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .task {
            await viewModel.startListeningIfNeeded()
        }
        .onDisappear {
            viewModel.cancelAndCleanup()
        }
    }

    // MARK: - Top Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            if let groupName = viewModel.groupName {
                Label(groupName, systemImage: "person.3.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.brand)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.brand.opacity(0.14), in: Capsule())
            } else {
                Label("BoloSplit AI", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.brand)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.brand.opacity(0.14), in: Capsule())
            }

            Spacer()

            Button {
                viewModel.toggleMute()
            } label: {
                Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.isMuted ? .secondary : AppTheme.brand)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel(viewModel.isMuted ? "Unmute voice replies" : "Mute voice replies")

            Button {
                viewModel.cancelAndCleanup()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Close voice overlay")
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private var contentBody: some View {
        switch viewModel.state {
        case .idle, .listening:
            listeningBody
        case .processing(let statusText):
            processingBody(statusText: statusText)
        case .typing:
            typingBody
        case .success(let response):
            VoiceResultCard(response: response)
        case .ambiguous(let clarification, _):
            ambiguousBody(clarification: clarification)
        case .permissionDenied:
            permissionDeniedBody
        case .error(let message):
            errorBody(message: message)
        }
    }

    private var listeningBody: some View {
        VStack(spacing: 18) {
            SiriGlowingOrb(
                audioLevel: viewModel.audioLevel,
                isProcessing: false
            )
            .frame(width: 164, height: 164)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Listening  \(formattedDuration(viewModel.elapsedTime))")
                        .font(.headline.monospacedDigit())
                }

                Text("Speak in Hinglish or English — e.g. \"500 chai nashta split with Sahaj\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    private func processingBody(statusText: String) -> some View {
        VStack(spacing: 20) {
            SiriGlowingOrb(
                audioLevel: 0.35,
                isProcessing: true
            )
            .frame(width: 148, height: 148)

            VStack(spacing: 6) {
                ProgressView()
                    .tint(AppTheme.brand)
                Text(statusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var typingBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Type your expense or query")
                .font(.headline)

            TextField(
                "e.g. Add 450 coffee split equally with Rahul",
                text: $viewModel.typedCommand,
                axis: .vertical
            )
            .lineLimit(2...4)
            .textFieldStyle(.plain)
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.brand.opacity(0.35), lineWidth: 1)
            )
            .focused($isTextFieldFocused)
            .submitLabel(.send)
            .onSubmit {
                viewModel.submitTypedCommand()
            }
            .onAppear {
                isTextFieldFocused = true
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Try one:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(quickExamples, id: \.self) { sample in
                    Button {
                        viewModel.typedCommand = sample
                    } label: {
                        Text("“\(sample)”")
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func ambiguousBody(clarification: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(.orange)

            Text("Quick Clarification")
                .font(.title3.bold())

            Text(clarification)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var permissionDeniedBody: some View {
        VStack(spacing: 14) {
            Image(systemName: "mic.slash.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Microphone Access Needed")
                .font(.title3.bold())

            Text("Enable Microphone permission in iOS Settings to speak expenses, or type your command below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func errorBody(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.owedNegative)

            Text("Didn't Catch That")
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Bottom Action Controls

    @ViewBuilder
    private var bottomActions: some View {
        switch viewModel.state {
        case .idle, .listening:
            HStack(spacing: 12) {
                Button {
                    viewModel.switchToTyping()
                } label: {
                    Label("Type", systemImage: "keyboard")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.finishAndSubmitRecording()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title3)
                        Text("End")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.red.opacity(0.92), AppTheme.owedNegative],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: .red.opacity(0.3), radius: 10, y: 4)
                }
            }

        case .processing:
            Button("Cancel") {
                viewModel.cancelAndCleanup()
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 10)

        case .typing:
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.startListening() }
                } label: {
                    Label("Speak", systemImage: "mic.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.submitTypedCommand()
                } label: {
                    Label("Send Command", systemImage: "arrow.up.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.brand, in: Capsule())
                }
                .disabled(viewModel.typedCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

        case .success:
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.startListening() }
                } label: {
                    Label("Speak Another", systemImage: "mic.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.cancelAndCleanup()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.brand, in: Capsule())
                }
            }

        case .ambiguous, .error:
            HStack(spacing: 12) {
                Button {
                    viewModel.switchToTyping()
                } label: {
                    Label("Type", systemImage: "keyboard")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.startListening() }
                } label: {
                    Label("Try Speaking Again", systemImage: "mic.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.brand, in: Capsule())
                }
            }

        case .permissionDenied:
            HStack(spacing: 12) {
                Button {
                    viewModel.switchToTyping()
                } label: {
                    Label("Type Instead", systemImage: "keyboard")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.brand, in: Capsule())
                }
            }
        }
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Audio-Reactive Siri Glowing Orb

private struct SiriGlowingOrb: View {
    let audioLevel: Float
    let isProcessing: Bool

    @State private var isPulsing = false

    private var normalizedLevel: CGFloat {
        CGFloat(min(max(audioLevel, 0.0), 1.0))
    }

    var body: some View {
        ZStack {
            // Outer reactive aura
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.brand.opacity(0.45),
                            Color.cyan.opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 86
                    )
                )
                .scaleEffect(0.86 + (normalizedLevel * 0.44) + (isPulsing ? 0.06 : 0.0))
                .animation(.spring(response: 0.16, dampingFraction: 0.65), value: normalizedLevel)

            // Middle glowing ring
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [.teal, .mint, .cyan, .indigo.opacity(0.75), .teal],
                        center: .center
                    ),
                    lineWidth: 3.5
                )
                .frame(width: 112, height: 112)
                .scaleEffect(0.95 + (normalizedLevel * 0.22))
                .rotationEffect(.degrees(isPulsing ? 360 : 0))
                .animation(
                    .linear(duration: isProcessing ? 1.8 : 6.0).repeatForever(autoreverses: false),
                    value: isPulsing
                )
                .animation(.spring(response: 0.14, dampingFraction: 0.7), value: normalizedLevel)

            // Core glowing sphere
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.teal, Color(red: 0.08, green: 0.74, blue: 0.64), .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .scaleEffect(0.96 + (normalizedLevel * 0.14))
                .shadow(color: AppTheme.brand.opacity(0.55), radius: 18)
                .overlay {
                    Image(systemName: isProcessing ? "sparkles" : "waveform")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, isActive: isProcessing)
                }
                .animation(.spring(response: 0.14, dampingFraction: 0.7), value: normalizedLevel)
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Compact Result Card

private struct VoiceResultCard: View {
    let response: VoiceIngestResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: badgeIcon)
                        .foregroundStyle(badgeColor)
                    Text(response.actionBadgeTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(badgeColor)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(badgeColor.opacity(0.12), in: Capsule())

                if let spoken = response.spokenConfirmation, !spoken.isEmpty {
                    Text(spoken)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Created / Updated Expenses
                if !response.expenses.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(response.expenses) { expense in
                            HStack(spacing: 12) {
                                Image(systemName: AppTheme.categoryIcon(for: expense.category))
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.brand)
                                    .frame(width: 36, height: 36)
                                    .background(AppTheme.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.description)
                                        .font(.subheadline.weight(.semibold))
                                    if expense.groupId == nil && expense.splits.count <= 1 {
                                        Text("Self (Personal) • \(expense.category?.capitalized ?? "General")")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.brand)
                                    } else {
                                        Text("Split among \(max(1, expense.splits.count)) • Paid by \(expense.payerName ?? "You")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(CurrencyFormatter.formatINR(expense.amount))
                                    .font(.subheadline.weight(.bold))
                            }
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }

                // Recorded Settlement
                if let settlement = response.settlement {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.owedPositive)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.owedPositive.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(settlement.payerName ?? "You") paid \(settlement.payeeName ?? "Friend")")
                                .font(.subheadline.weight(.semibold))
                            Text(settlement.paymentMethod)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(CurrencyFormatter.formatINR(settlement.amount))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.owedPositive)
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // GET Balance Snapshot
                if let summary = response.balanceSummary {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Owed to you")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CurrencyFormatter.formatINR(summary.totalOwedToYou))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.owedPositive)
                        }
                        HStack {
                            Text("You owe")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CurrencyFormatter.formatINR(summary.totalYouOwe))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.owedNegative)
                        }
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var badgeColor: Color {
        switch response.normalizedAction {
        case "DELETE":
            return AppTheme.owedNegative
        case "GET":
            return AppTheme.brand
        default:
            return AppTheme.owedPositive
        }
    }

    private var badgeIcon: String {
        switch response.normalizedAction {
        case "DELETE":
            return "trash.fill"
        case "SETTLE":
            return "checkmark.circle.fill"
        case "GET":
            return "indianrupeesign.circle.fill"
        default:
            return "checkmark.circle.fill"
        }
    }
}
