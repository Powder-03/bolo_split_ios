//
//  SiriVoiceOverlayView.swift
//  BoloSplit
//
//  Translucent Siri-like floating voice overlay with audio-reactive glowing orb,
//  animated state transitions, waveform meter, typed fallback, and staggered result cards.
//

import SwiftUI
import UIKit

struct SiriVoiceOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: VoiceViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var isRecordingDotPulsing = false

    private let quickExamples = [
        "Add 500 petrol split with Sahaj",
        "Maine Rahul ko 250 UPI kar diye",
        "What are my current balances?"
    ]

    private var stateTransitionKey: String {
        switch viewModel.state {
        case .idle, .listening: return "listening"
        case .processing: return "processing"
        case .typing: return "typing"
        case .success: return "success"
        case .ambiguous: return "ambiguous"
        case .permissionDenied: return "permissionDenied"
        case .error: return "error"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            headerBar

            Spacer(minLength: 4)

            contentBody
                .id(stateTransitionKey)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.94)).combined(with: .offset(y: 10)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    )
                )

            Spacer(minLength: 4)

            bottomActions
                .id("actions-\(stateTransitionKey)")
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .animation(AppMotion.snappy, value: stateTransitionKey)
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.brand.opacity(0.14), in: Capsule())
            } else {
                Label("BoloSplit AI", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.brand)
                    .padding(.horizontal, 12)
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
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(BoloPressButtonStyle(haptic: .light))
            .accessibilityLabel(viewModel.isMuted ? "Unmute voice replies" : "Mute voice replies")

            Button {
                viewModel.cancelAndCleanup()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(BoloPressButtonStyle(haptic: .light))
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
        VStack(spacing: 16) {
            SiriGlowingOrb(
                audioLevel: viewModel.audioLevel,
                isProcessing: false
            )
            .frame(width: 168, height: 168)

            AudioWaveformBars(audioLevel: viewModel.audioLevel)
                .frame(height: 24)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isRecordingDotPulsing ? 1.25 : 0.75)
                        .opacity(isRecordingDotPulsing ? 1.0 : 0.45)
                        .onAppear {
                            guard !reduceMotion, !isRecordingDotPulsing else { return }
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                isRecordingDotPulsing = true
                            }
                        }

                    Text("Listening  \(formattedDuration(viewModel.elapsedTime))")
                        .font(.headline.monospacedDigit())
                        .contentTransition(.numericText())
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
                audioLevel: 0.4,
                isProcessing: true
            )
            .frame(width: 152, height: 152)

            VStack(spacing: 8) {
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
                    .strokeBorder(AppTheme.brand.opacity(0.45), lineWidth: 1.2)
            )
            .focused($isTextFieldFocused)
            .submitLabel(.send)
            .onSubmit {
                viewModel.submitTypedCommand()
            }
            .onAppear {
                isTextFieldFocused = true
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Try one:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(quickExamples.enumerated()), id: \.element) { index, sample in
                    Button {
                        withAnimation(AppMotion.snappy) {
                            viewModel.typedCommand = sample
                        }
                    } label: {
                        HStack {
                            Text("“\(sample)”")
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.brand)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(BoloPressButtonStyle(scale: 0.98, haptic: .light))
                    .staggeredEntrance(index: index)
                }
            }
        }
    }

    private func ambiguousBody(clarification: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.14))
                    .frame(width: 72, height: 72)
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, value: stateTransitionKey)
            }

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
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.14))
                    .frame(width: 76, height: 76)
                Image(systemName: "mic.slash.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
            }

            Text("Microphone Access Needed")
                .font(.title3.bold())

            Text("Enable Microphone permission in iOS Settings to speak expenses, or type your command below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var errorHeadline: String {
        switch viewModel.lastErrorCode?.uppercased() {
        case "UNCLEAR_AUDIO":
            return "Sound Was Not Clear"
        case "UNKNOWN_FRIEND":
            return "Friend Not Found"
        case "UNKNOWN_GROUP":
            return "Group Not Found"
        case "INVALID_AMOUNT":
            return "Amount Was Unclear"
        case "UNRESOLVED_SPLIT":
            return "Split Was Unclear"
        default:
            return "Didn't Catch That"
        }
    }

    private var errorIconName: String {
        switch viewModel.lastErrorCode?.uppercased() {
        case "UNCLEAR_AUDIO":
            return "waveform.slash"
        case "UNKNOWN_FRIEND":
            return "person.crop.circle.badge.questionmark"
        case "UNKNOWN_GROUP":
            return "person.3.sequence.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }

    private func errorBody(message: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.owedNegative.opacity(0.14))
                    .frame(width: 72, height: 72)
                Image(systemName: errorIconName)
                    .font(.system(size: 38))
                    .foregroundStyle(AppTheme.owedNegative)
                    .symbolEffect(.bounce, value: stateTransitionKey)
            }

            Text(errorHeadline)
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
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(BoloPressButtonStyle(haptic: .light))

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
                    .shadow(color: .red.opacity(0.32), radius: 10, y: 4)
                }
                .buttonStyle(BoloPressButtonStyle(haptic: .medium))
            }

        case .processing:
            Button("Cancel") {
                viewModel.cancelAndCleanup()
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .buttonStyle(BoloPressButtonStyle(haptic: .light))

        case .typing:
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.startListening() }
                } label: {
                    Label("Speak", systemImage: "mic.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(BoloPressButtonStyle(haptic: .light))

                let isEmpty = viewModel.typedCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button {
                    viewModel.submitTypedCommand()
                } label: {
                    Label("Send Command", systemImage: "arrow.up.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isEmpty ? AnyShapeStyle(Color.secondary.opacity(0.4)) : AnyShapeStyle(AppTheme.brandGradient), in: Capsule())
                }
                .buttonStyle(BoloPressButtonStyle(haptic: .medium))
                .disabled(isEmpty)
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
                .buttonStyle(BoloPressButtonStyle(haptic: .light))

                Button {
                    viewModel.cancelAndCleanup()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.brandGradient, in: Capsule())
                        .shadow(color: AppTheme.brand.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(BoloPressButtonStyle(haptic: .light))
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
                .buttonStyle(BoloPressButtonStyle(haptic: .light))

                Button {
                    Task { await viewModel.startListening() }
                } label: {
                    Label("Try Speaking Again", systemImage: "mic.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.brandGradient, in: Capsule())
                }
                .buttonStyle(BoloPressButtonStyle(haptic: .medium))
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
                .buttonStyle(BoloPressButtonStyle(haptic: .light))

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
                        .background(AppTheme.brandGradient, in: Capsule())
                }
                .buttonStyle(BoloPressButtonStyle(haptic: .light))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let audioLevel: Float
    let isProcessing: Bool

    @State private var isSpinning = false
    @State private var sonarPulse = false

    private var normalizedLevel: CGFloat {
        CGFloat(min(max(audioLevel, 0.0), 1.0))
    }

    var body: some View {
        ZStack {
            // Sonar wave ripple when listening
            if !isProcessing && !reduceMotion {
                Circle()
                    .stroke(AppTheme.brand.opacity(sonarPulse ? 0.0 : 0.35), lineWidth: 2)
                    .frame(width: 112, height: 112)
                    .scaleEffect(sonarPulse ? 1.55 + (normalizedLevel * 0.2) : 0.95)
            }

            // Outer reactive aura
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.brand.opacity(0.48),
                            Color.cyan.opacity(0.20),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 88
                    )
                )
                .scaleEffect(0.86 + (normalizedLevel * 0.46) + (isSpinning ? 0.05 : 0.0))
                .animation(.spring(response: 0.16, dampingFraction: 0.65), value: normalizedLevel)

            // Secondary counter-rotating ring
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [.cyan.opacity(0.7), .mint.opacity(0.3), .teal.opacity(0.8), .clear, .cyan.opacity(0.7)],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 126, height: 126)
                .scaleEffect(0.92 + (normalizedLevel * 0.28))
                .rotationEffect(.degrees(isSpinning ? -360 : 0))
                .animation(
                    reduceMotion ? nil : .linear(duration: isProcessing ? 2.2 : 8.0).repeatForever(autoreverses: false),
                    value: isSpinning
                )
                .animation(.spring(response: 0.16, dampingFraction: 0.7), value: normalizedLevel)

            // Primary glowing ring
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
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    reduceMotion ? nil : .linear(duration: isProcessing ? 1.6 : 5.5).repeatForever(autoreverses: false),
                    value: isSpinning
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
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.32), lineWidth: 1)
                )
                .scaleEffect(0.96 + (normalizedLevel * 0.14))
                .shadow(color: AppTheme.brand.opacity(0.55), radius: 18)
                .overlay {
                    Image(systemName: isProcessing ? "sparkles" : "waveform")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.pulse, isActive: isProcessing && !reduceMotion)
                }
                .animation(.spring(response: 0.14, dampingFraction: 0.7), value: normalizedLevel)
        }
        .onAppear {
            guard !reduceMotion else { return }
            isSpinning = true
            withAnimation(.easeOut(duration: 1.9).repeatForever(autoreverses: false)) {
                sonarPulse = true
            }
        }
    }
}

// MARK: - Live Audio Waveform Bars

private struct AudioWaveformBars: View {
    let audioLevel: Float
    private let multipliers: [CGFloat] = [0.42, 0.72, 0.96, 1.0, 0.88, 0.64, 0.40]

    private var level: CGFloat {
        CGFloat(min(max(audioLevel, 0.06), 1.0))
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<multipliers.count, id: \.self) { index in
                Capsule()
                    .fill(AppTheme.brandGradient)
                    .frame(width: 4, height: max(5, 24 * level * multipliers[index]))
                    .animation(
                        .spring(response: 0.14, dampingFraction: 0.62).delay(Double(index) * 0.012),
                        value: level
                    )
            }
        }
    }
}

// MARK: - Compact Result Card

private struct VoiceResultCard: View {
    let response: VoiceIngestResponse
    @State private var badgeAppeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: badgeIcon)
                        .foregroundStyle(badgeColor)
                        .symbolEffect(.bounce, value: badgeAppeared)
                    Text(response.actionBadgeTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(badgeColor)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(badgeColor.opacity(0.12), in: Capsule())
                .staggeredEntrance(index: 0)

                if let spoken = response.spokenConfirmation, !spoken.isEmpty {
                    Text(spoken)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .staggeredEntrance(index: 1)
                }

                // Created / Updated Expenses
                if !response.expenses.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(Array(response.expenses.enumerated()), id: \.element.id) { idx, expense in
                            let catColor = AppTheme.categoryColor(for: expense.category)
                            HStack(spacing: 12) {
                                Image(systemName: AppTheme.categoryIcon(for: expense.category))
                                    .font(.headline)
                                    .foregroundStyle(catColor)
                                    .frame(width: 38, height: 38)
                                    .background(catColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.description)
                                        .font(.subheadline.weight(.semibold))
                                    if expense.isSoloExpense {
                                        Text("Self (Personal) • \(expense.category?.capitalized ?? "General")")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.brand)
                                    } else if expense.groupId == nil && expense.splits.count == 1 {
                                        Text("Charged to friend • Paid by \(expense.payerName ?? "You")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
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
                            .staggeredEntrance(index: idx + 2)
                        }
                    }
                }

                // Recorded Settlement
                if let settlement = response.settlement {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(AppTheme.owedPositive)
                            .frame(width: 38, height: 38)
                            .background(AppTheme.owedPositive.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

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
                    .staggeredEntrance(index: 2)
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
                    .staggeredEntrance(index: 2)
                }
            }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            badgeAppeared = true
        }
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
