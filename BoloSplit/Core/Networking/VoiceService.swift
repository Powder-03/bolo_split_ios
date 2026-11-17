//
//  VoiceService.swift
//  BoloSplit
//
//  Networking service for POST /voice/audio and POST /voice/text.
//

import Foundation

protocol VoiceServiceProtocol {
    func sendVoiceAudio(fileURL: URL, groupId: UUID?) async throws -> VoiceIngestResponse
    func sendVoiceText(_ text: String, groupId: UUID?) async throws -> VoiceIngestResponse
}

final class VoiceService: VoiceServiceProtocol {
    private let apiClient: APIClientProtocol

    private static let localISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func sendVoiceAudio(fileURL: URL, groupId: UUID?) async throws -> VoiceIngestResponse {
        var fields: [String: String] = [
            "client_timestamp_iso": Self.localISOFormatter.string(from: Date())
        ]
        if let groupId {
            fields["group_id"] = groupId.uuidString
        }

        return try await apiClient.uploadAudio(
            path: "/voice/audio",
            fileURL: fileURL,
            fields: fields
        )
    }

    func sendVoiceText(_ text: String, groupId: UUID?) async throws -> VoiceIngestResponse {
        let payload = VoiceCommandRequest(
            text: text,
            clientTimestampIso: Self.localISOFormatter.string(from: Date()),
            groupId: groupId
        )
        let endpoint = try Endpoint.post("/voice/text", body: payload)
        return try await apiClient.request(endpoint)
    }
}
