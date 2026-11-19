//
//  VoiceViewModelTests.swift
//  BoloSplitTests
//
//  Unit tests covering VoiceViewModel state transitions:
//  idle -> listening -> processing -> success / ambiguous / error,
//  plus text input fallback and speech synthesis invocation (US-3.1 to US-3.5, US-8.1).
//

import XCTest
@testable import BoloSplit

@MainActor
final class VoiceViewModelTests: XCTestCase {
    private var mockRecorder: MockAudioRecorderService!
    private var mockSpeech: MockSpeechPlaybackService!
    private var mockVoiceService: MockVoiceService!
    private var viewModel: VoiceViewModel!
    private var ledgerMutatedCalled = false

    override func setUp() {
        super.setUp()
        mockRecorder = MockAudioRecorderService()
        mockSpeech = MockSpeechPlaybackService()
        mockVoiceService = MockVoiceService()
        ledgerMutatedCalled = false

        viewModel = VoiceViewModel(
            recorder: mockRecorder,
            speechService: mockSpeech,
            voiceService: mockVoiceService,
            groupId: nil,
            groupName: nil,
            onLedgerMutated: { [weak self] in
                self?.ledgerMutatedCalled = true
            }
        )
    }

    override func tearDown() {
        viewModel = nil
        mockVoiceService = nil
        mockSpeech = nil
        mockRecorder = nil
        super.tearDown()
    }

    func testInitialStateIsIdle() {
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.typedCommand, "")
        XCTAssertFalse(viewModel.isSpeaking)
    }

    func testStartListeningSuccess() async {
        mockRecorder.permissionGranted = true
        await viewModel.startListening()

        XCTAssertEqual(viewModel.state, .listening)
        XCTAssertTrue(mockRecorder.didStartRecording)
        XCTAssertTrue(mockSpeech.didCallStop)
    }

    func testStartListeningPermissionDenied() async {
        mockRecorder.permissionGranted = false
        await viewModel.startListening()

        XCTAssertEqual(viewModel.state, .permissionDenied)
        XCTAssertFalse(mockRecorder.didStartRecording)
    }

    func testFinishAndSubmitRecordingSuccess() async {
        mockRecorder.permissionGranted = true
        await viewModel.startListening()
        XCTAssertEqual(viewModel.state, .listening)

        viewModel.finishAndSubmitRecording()

        // Wait a brief moment for background Task to finish
        try? await Task.sleep(nanoseconds: 50_000_000)

        guard case .success(let response) = viewModel.state else {
            XCTFail("Expected .success state, got \(viewModel.state)")
            return
        }

        XCTAssertEqual(response.spokenConfirmation, "Added 500 petrol split with Sahaj")
        XCTAssertTrue(mockVoiceService.didSendAudio)
        XCTAssertEqual(mockSpeech.lastSpokenText, "Added 500 petrol split with Sahaj")
        XCTAssertTrue(ledgerMutatedCalled)
    }

    func testFinishAndSubmitRecordingAmbiguous() async {
        mockVoiceService.mockAudioResponse = VoiceIngestResponse(
            status: "AMBIGUOUS",
            spokenConfirmation: "Did you mean Sahaj Patel or Sahaj Sharma?",
            isAmbiguous: true,
            clarificationPrompt: "Found multiple friends named Sahaj. Which one?"
        )

        mockRecorder.permissionGranted = true
        await viewModel.startListening()
        viewModel.finishAndSubmitRecording()

        try? await Task.sleep(nanoseconds: 50_000_000)

        guard case .ambiguous(let clarification, let spokenConfirmation) = viewModel.state else {
            XCTFail("Expected .ambiguous state, got \(viewModel.state)")
            return
        }

        XCTAssertEqual(clarification, "Found multiple friends named Sahaj. Which one?")
        XCTAssertEqual(spokenConfirmation, "Did you mean Sahaj Patel or Sahaj Sharma?")
        XCTAssertEqual(mockSpeech.lastSpokenText, "Did you mean Sahaj Patel or Sahaj Sharma?")
    }

    func testFinishAndSubmitRecordingNetworkError() async {
        mockVoiceService.shouldThrowError = APIError.httpError(statusCode: 502, message: "Bad Gateway")

        mockRecorder.permissionGranted = true
        await viewModel.startListening()
        viewModel.finishAndSubmitRecording()

        try? await Task.sleep(nanoseconds: 50_000_000)

        guard case .error(let message) = viewModel.state else {
            XCTFail("Expected .error state, got \(viewModel.state)")
            return
        }

        XCTAssertTrue(message.contains("502") || message.contains("Bad Gateway"))
    }

    func testSubmitTypedCommandFallback() async {
        viewModel.switchToTyping()
        XCTAssertEqual(viewModel.state, .typing)

        viewModel.typedCommand = "Add 250 chai split with Rahul"
        viewModel.submitTypedCommand()

        try? await Task.sleep(nanoseconds: 50_000_000)

        guard case .success(let response) = viewModel.state else {
            XCTFail("Expected .success state, got \(viewModel.state)")
            return
        }

        XCTAssertEqual(mockVoiceService.lastSubmittedText, "Add 250 chai split with Rahul")
        XCTAssertEqual(response.spokenConfirmation, "Added 250 chai split with Rahul")
        XCTAssertEqual(viewModel.typedCommand, "")
    }

    func testToggleMute() {
        XCTAssertFalse(viewModel.isMuted)
        viewModel.toggleMute()
        XCTAssertTrue(viewModel.isMuted)
        viewModel.toggleMute()
        XCTAssertFalse(viewModel.isMuted)
    }

    func testCancelAndCleanup() async {
        mockRecorder.permissionGranted = true
        await viewModel.startListening()
        XCTAssertTrue(mockRecorder.isRecording)

        viewModel.cancelAndCleanup()
        XCTAssertTrue(mockRecorder.didCancelRecording)
        XCTAssertTrue(mockSpeech.didCallStop)
    }
}
