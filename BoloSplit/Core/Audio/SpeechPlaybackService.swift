//
//  SpeechPlaybackService.swift
//  BoloSplit
//
//  AVSpeechSynthesizer wrapper for spoken Hinglish/English ledger confirmations.
//

import AVFoundation
import Foundation
import Observation

protocol SpeechPlaybackServiceProtocol {
    var isSpeaking: Bool { get }
    var isMuted: Bool { get set }

    func speak(_ text: String)
    func stop()
}

@Observable
final class SpeechPlaybackService: NSObject, SpeechPlaybackServiceProtocol, AVSpeechSynthesizerDelegate {
    private static let mutedKey = "bolosplit_tts_muted"

    private let synthesizer = AVSpeechSynthesizer()

    private(set) var isSpeaking = false
    var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: Self.mutedKey)
            if isMuted {
                stop()
            }
        }
    }

    override init() {
        self.isMuted = UserDefaults.standard.bool(forKey: Self.mutedKey)
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isMuted, !trimmed.isEmpty else { return }

        stop()

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.02
        utterance.pitchMultiplier = 1.02

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }
}
