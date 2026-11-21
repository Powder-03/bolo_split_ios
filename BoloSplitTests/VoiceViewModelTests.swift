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

    func testFinishAndSubmitRecordingBackendUnclearAudioError() async {
        mockVoiceService.mockAudioResponse = VoiceIngestResponse(
            status: "ERROR",
            actionType: "UNKNOWN",
            count: 0,
            expenses: [],
            spokenConfirmation: "Sound was not clear. Please speak again clearly.",
            isAmbiguous: false,
            clarificationPrompt: "Sound was not clear. Please speak again clearly.",
            errorCode: "UNCLEAR_AUDIO"
        )

        mockRecorder.permissionGranted = true
        await viewModel.startListening()
        viewModel.finishAndSubmitRecording()

        try? await Task.sleep(nanoseconds: 50_000_000)

        guard case .error(let message) = viewModel.state else {
            XCTFail("Expected .error state, got \(viewModel.state)")
            return
        }

        XCTAssertEqual(message, "Sound was not clear. Please speak again clearly.")
        XCTAssertEqual(viewModel.lastErrorCode, "UNCLEAR_AUDIO")
        XCTAssertEqual(mockSpeech.lastSpokenText, "Sound was not clear. Please speak again clearly.")
        XCTAssertFalse(ledgerMutatedCalled)
    }

    func testSubmitTypedCommandPreservesTextOnBackendError() async {
        mockVoiceService.mockTextResponse = VoiceIngestResponse(
            status: "ERROR",
            actionType: "CREATE",
            count: 0,
            expenses: [],
            spokenConfirmation: "Couldn't find friend 'Rishab'. Please speak again using their nickname or add them first.",
            isAmbiguous: false,
            clarificationPrompt: "Couldn't find friend 'Rishab'. Please speak again using their nickname or add them first.",
            errorCode: "UNKNOWN_FRIEND"
        )

        viewModel.switchToTyping()
        viewModel.typedCommand = "add 200 on rishab"
        viewModel.submitTypedCommand()

        try? await Task.sleep(nanoseconds: 50_000_000)

        guard case .error(let message) = viewModel.state else {
            XCTFail("Expected .error state, got \(viewModel.state)")
            return
        }

        XCTAssertEqual(viewModel.lastErrorCode, "UNKNOWN_FRIEND")
        XCTAssertTrue(message.contains("Rishab"))
        XCTAssertEqual(viewModel.typedCommand, "add 200 on rishab")
        XCTAssertFalse(ledgerMutatedCalled)
    }

    func testVoiceIngestResponseDecodesSnakeCaseErrorCode() throws {
        let json = """
        {
          "status": "ERROR",
          "action_type": "UNKNOWN",
          "count": 0,
          "expenses": [],
          "spoken_confirmation": "Sound was not clear. Please speak again clearly.",
          "is_ambiguous": false,
          "clarification_prompt": "Sound was not clear. Please speak again clearly.",
          "error_code": "UNCLEAR_AUDIO"
        }
        """.data(using: .utf8)!

        let decoded = try JSONCoders.decoder.decode(VoiceIngestResponse.self, from: json)
        XCTAssertEqual(decoded.status, "ERROR")
        XCTAssertEqual(decoded.actionType, "UNKNOWN")
        XCTAssertEqual(decoded.count, 0)
        XCTAssertEqual(decoded.errorCode, "UNCLEAR_AUDIO")
        XCTAssertEqual(decoded.spokenConfirmation, "Sound was not clear. Please speak again clearly.")
    }
}
