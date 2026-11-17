//
//  VoiceViewModel.swift
//  BoloSplit
//
//  MVVM ViewModel orchestrating Siri-like voice capture, audio/text upload,
//  ambiguity clarification, ledger refresh, and spoken confirmation playback.
//

import Foundation
import Observation
import UIKit

enum VoiceOverlayState: Equatable {
    case idle
    case permissionDenied
    case listening
    case typing
    case processing(String)
    case success(VoiceIngestResponse)
    case ambiguous(clarification: String, spokenConfirmation: String?)
    case error(String)
}

@Observable
final class VoiceViewModel {
    private let recorder: any AudioRecorderServiceProtocol
    private var speechService: any SpeechPlaybackServiceProtocol
    private let voiceService: any VoiceServiceProtocol
    private let onLedgerMutated: (() async -> Void)?

    let groupId: UUID?
    let groupName: String?

    private(set) var state: VoiceOverlayState = .idle
    var typedCommand: String = ""

    private var activeTask: Task<Void, Never>?

    var audioLevel: Float {
        recorder.currentLevel
    }

    var elapsedTime: TimeInterval {
        recorder.elapsedTime
    }

    var isMuted: Bool {
        get { speechService.isMuted }
        set { speechService.isMuted = newValue }
    }

    var isSpeaking: Bool {
        speechService.isSpeaking
    }

    init(
        recorder: any AudioRecorderServiceProtocol,
        speechService: any SpeechPlaybackServiceProtocol,
        voiceService: any VoiceServiceProtocol,
        groupId: UUID? = nil,
        groupName: String? = nil,
        onLedgerMutated: (() async -> Void)? = nil
    ) {
        self.recorder = recorder
        self.speechService = speechService
        self.voiceService = voiceService
        self.groupId = groupId
        self.groupName = groupName
        self.onLedgerMutated = onLedgerMutated
    }

    func startListeningIfNeeded() async {
        guard case .idle = state else { return }
        await startListening()
    }

    func startListening() async {
        activeTask?.cancel()
        speechService.stop()

        do {
            try await recorder.startRecording()
            state = .listening
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch AudioRecorderError.permissionDenied {
            state = .permissionDenied
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func finishAndSubmitRecording() {
        guard case .listening = state else { return }

        let fileURL: URL
        do {
            fileURL = try recorder.stopRecording()
        } catch {
            state = .error(error.localizedDescription)
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state = .processing("Listening complete • Understanding Hinglish & splitting...")

        activeTask?.cancel()
        activeTask = Task { [weak self] in
            guard let self else { return }
            defer {
                try? FileManager.default.removeItem(at: fileURL)
            }

            do {
                let response = try await voiceService.sendVoiceAudio(
                    fileURL: fileURL,
                    groupId: groupId
                )
                guard !Task.isCancelled else { return }
                await handleVoiceResponse(response)
            } catch {
                guard !Task.isCancelled else { return }
                state = .error(error.localizedDescription)
            }
        }
    }

    func switchToTyping() {
        activeTask?.cancel()
        recorder.cancelRecording()
        speechService.stop()
        state = .typing
    }

    func submitTypedCommand() {
        let trimmed = typedCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        speechService.stop()
        state = .processing("Processing command...")

        activeTask?.cancel()
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await voiceService.sendVoiceText(trimmed, groupId: groupId)
                guard !Task.isCancelled else { return }
                typedCommand = ""
                await handleVoiceResponse(response)
            } catch {
                guard !Task.isCancelled else { return }
                state = .error(error.localizedDescription)
            }
        }
    }

    func toggleMute() {
        isMuted.toggle()
    }

    func cancelAndCleanup() {
        activeTask?.cancel()
        activeTask = nil
        recorder.cancelRecording()
        speechService.stop()
    }

    // MARK: - Helpers

    private func handleVoiceResponse(_ response: VoiceIngestResponse) async {
        let upperStatus = response.status.uppercased()

        if response.isAmbiguous || upperStatus == "AMBIGUOUS" {
            let prompt = response.clarificationPrompt
                ?? response.spokenConfirmation
                ?? "Found multiple matching records. Please clarify."
            state = .ambiguous(
                clarification: prompt,
                spokenConfirmation: response.spokenConfirmation
            )
            speechService.speak(response.spokenConfirmation ?? prompt)
            return
        }

        if upperStatus == "ERROR" {
            state = .error(response.spokenConfirmation ?? "Could not process voice command.")
            return
        }

        state = .success(response)
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if let spoken = response.spokenConfirmation {
            speechService.speak(spoken)
        }

        if response.mutatesLedger, let onLedgerMutated {
            await onLedgerMutated()
        }
    }
}
