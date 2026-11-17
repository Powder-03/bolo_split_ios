//
//  APIError.swift
//  BoloSplit
//
//  Typed networking & backend error representation.
//

import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case unauthorized(String)
    case httpError(statusCode: Int, message: String)
    case decodingError(String)
    case networkError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL configuration."
        case .unauthorized(let message):
            return message.isEmpty ? "Session expired. Please sign in again." : message
        case .httpError(let statusCode, let message):
            return message.isEmpty ? "Server error (HTTP \(statusCode))." : message
        case .decodingError(let details):
            return "Failed to parse server response: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        case .timeout:
            return "Request timed out. Please try again."
        }
    }

    static func parseServerMessage(from data: Data) -> String {
        guard !data.isEmpty else { return "" }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = json["detail"] as? String {
                return detail
            }
            if let detailArray = json["detail"] as? [[String: Any]],
               let firstMsg = detailArray.first?["msg"] as? String {
                return firstMsg
            }
            if let message = json["message"] as? String {
                return message
            }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
