//
//  MockAudioRecorderService.swift
//  BoloSplitTests
//
//  Mock audio recorder for testing VoiceViewModel state transitions.
//

import Foundation
@testable import BoloSplit

final class MockAudioRecorderService: AudioRecorderServiceProtocol {
    var isRecording = false
    var currentLevel: Float = 0.5
    var elapsedTime: TimeInterval = 2.5

    var permissionGranted = true
    var shouldThrowOnStart: Error?
    var shouldThrowOnStop: Error?

    var didStartRecording = false
    var didStopRecording = false
    var didCancelRecording = false

    func requestPermission() async -> Bool {
        permissionGranted
    }

    func startRecording() async throws {
        if !permissionGranted {
            throw AudioRecorderError.permissionDenied
        }
        if let shouldThrowOnStart {
            throw shouldThrowOnStart
        }
        isRecording = true
        didStartRecording = true
    }

    func stopRecording() throws -> URL {
        if let shouldThrowOnStop {
            throw shouldThrowOnStop
        }
        isRecording = false
        didStopRecording = true
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try? "dummy audio bytes".write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    func cancelRecording() {
        isRecording = false
        didCancelRecording = true
    }
}
