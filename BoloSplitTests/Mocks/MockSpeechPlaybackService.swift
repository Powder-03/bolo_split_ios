//
//  MockSpeechPlaybackService.swift
//  BoloSplitTests
//
//  Mock speech playback service for testing VoiceViewModel TTS integration.
//

import Foundation
@testable import BoloSplit

final class MockSpeechPlaybackService: SpeechPlaybackServiceProtocol {
    var isSpeaking = false
    var isMuted = false

    var lastSpokenText: String?
    var didCallStop = false

    func speak(_ text: String) {
        lastSpokenText = text
        if !isMuted {
            isSpeaking = true
        }
    }

    func stop() {
        isSpeaking = false
        didCallStop = true
    }
}
