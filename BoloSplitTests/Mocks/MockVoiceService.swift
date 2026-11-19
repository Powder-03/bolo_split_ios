//
//  MockVoiceService.swift
//  BoloSplitTests
//
//  Mock voice service for testing VoiceViewModel audio & text command ingestion.
//

import Foundation
@testable import BoloSplit

final class MockVoiceService: VoiceServiceProtocol {
    var mockAudioResponse: VoiceIngestResponse = VoiceIngestResponse(
        status: "SUCCESS",
        actionType: "CREATE",
        count: 1,
        expenses: [],
        settlement: nil,
        balanceSummary: nil,
        spokenConfirmation: "Added 500 petrol split with Sahaj",
        isAmbiguous: false,
        clarificationPrompt: nil
    )

    var mockTextResponse: VoiceIngestResponse = VoiceIngestResponse(
        status: "SUCCESS",
        actionType: "CREATE",
        count: 1,
        expenses: [],
        settlement: nil,
        balanceSummary: nil,
        spokenConfirmation: "Added 250 chai split with Rahul",
        isAmbiguous: false,
        clarificationPrompt: nil
    )

    var shouldThrowError: Error?
    var lastSubmittedText: String?
    var didSendAudio = false

    func sendVoiceAudio(fileURL: URL, groupId: UUID?) async throws -> VoiceIngestResponse {
        if let shouldThrowError { throw shouldThrowError }
        didSendAudio = true
        return mockAudioResponse
    }

    func sendVoiceText(_ text: String, groupId: UUID?) async throws -> VoiceIngestResponse {
        if let shouldThrowError { throw shouldThrowError }
        lastSubmittedText = text
        return mockTextResponse
    }
}
