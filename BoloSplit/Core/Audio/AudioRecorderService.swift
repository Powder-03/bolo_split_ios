//
//  AudioRecorderService.swift
//  BoloSplit
//
//  AVAudioRecorder wrapper capturing .m4a audio with live normalized decibel metering.
//

import AVFoundation
import Foundation
import Observation

enum AudioRecorderError: LocalizedError, Equatable {
    case permissionDenied
    case failedToStart(String)
    case noActiveRecording
    case emptyRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access is required to record voice commands."
        case .failedToStart(let reason):
            return "Could not start recording: \(reason)"
        case .noActiveRecording:
            return "No active recording was found."
        case .emptyRecording:
            return "No audio was captured. Please try speaking again."
        }
    }
}

protocol AudioRecorderServiceProtocol {
    var isRecording: Bool { get }
    var currentLevel: Float { get }
    var elapsedTime: TimeInterval { get }

    func requestPermission() async -> Bool
    func startRecording() async throws
    func stopRecording() throws -> URL
    func cancelRecording()
}

@Observable
final class AudioRecorderService: AudioRecorderServiceProtocol {
    private(set) var isRecording = false
    private(set) var currentLevel: Float = 0
    private(set) var elapsedTime: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var meteringTimer: Timer?

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func startRecording() async throws {
        let granted = await requestPermission()
        guard granted else {
            throw AudioRecorderError.permissionDenied
        }

        // Clean up any stale session/file before starting
        cancelRecording()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setActive(true)
        } catch {
            throw AudioRecorderError.failedToStart(error.localizedDescription)
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bolosplit-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            newRecorder.isMeteringEnabled = true
            guard newRecorder.prepareToRecord(), newRecorder.record() else {
                throw AudioRecorderError.failedToStart("Audio hardware could not initialize.")
            }
            self.recorder = newRecorder
            self.recordingURL = fileURL
            self.isRecording = true
            self.elapsedTime = 0
            self.currentLevel = 0.08
            startMeteringTimer()
        } catch let error as AudioRecorderError {
            throw error
        } catch {
            throw AudioRecorderError.failedToStart(error.localizedDescription)
        }
    }

    func stopRecording() throws -> URL {
        stopMeteringTimer()

        guard let recorder, let fileURL = recordingURL else {
            isRecording = false
            throw AudioRecorderError.noActiveRecording
        }

        recorder.stop()
        self.recorder = nil
        self.recordingURL = nil
        self.isRecording = false
        self.currentLevel = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        guard FileManager.default.fileExists(atPath: fileURL.path), fileSize > 256 else {
            try? FileManager.default.removeItem(at: fileURL)
            throw AudioRecorderError.emptyRecording
        }

        return fileURL
    }

    func cancelRecording() {
        stopMeteringTimer()
        recorder?.stop()
        recorder = nil

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        isRecording = false
        currentLevel = 0
        elapsedTime = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Metering

    private func startMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMeter()
            }
        }
    }

    private func stopMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    private func updateMeter() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        elapsedTime = recorder.currentTime

        // Map decibels (-55 dB silence ... -4 dB loud speech) to 0.0...1.0
        let power = recorder.averagePower(forChannel: 0)
        let minDb: Float = -55.0
        let maxDb: Float = -4.0
        let clamped = min(max(power, minDb), maxDb)
        let normalized = (clamped - minDb) / (maxDb - minDb)
        // Smooth rise & gentle decay for fluid Siri-like orb motion
        currentLevel = (currentLevel * 0.45) + (normalized * 0.55)
    }
}
