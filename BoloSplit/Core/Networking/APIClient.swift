//
//  APIClient.swift
//  BoloSplit
//
//  Async/await networking client with Firebase/Dev auth injection,
//  automatic 401 token refresh, and multipart upload.
//

import Foundation

protocol AuthHeaderProviding {
    func authHeaders(forceRefresh: Bool) async throws -> [String: String]
}

protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func requestVoid(_ endpoint: Endpoint) async throws
    func uploadAudio<T: Decodable>(
        path: String,
        fileURL: URL,
        fields: [String: String]
    ) async throws -> T
}

final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let authProvider: AuthHeaderProviding

    init(
        baseURL: URL = AppConfig.baseURL,
        session: URLSession = .shared,
        authProvider: AuthHeaderProviding
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authProvider = authProvider
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await executeWithRetry(endpoint)
        do {
            return try JSONCoders.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    func requestVoid(_ endpoint: Endpoint) async throws {
        _ = try await executeWithRetry(endpoint)
    }

    func uploadAudio<T: Decodable>(
        path: String,
        fileURL: URL,
        fields: [String: String]
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        let fileData = try Data(contentsOf: fileURL)

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        let filename = fileURL.lastPathComponent.isEmpty ? "voice.m4a" : fileURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let endpoint = Endpoint(
            path: path,
            method: .post,
            body: body,
            requiresAuth: true,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        let data = try await executeWithRetry(endpoint)
        do {
            return try JSONCoders.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Internal Request Execution

    private func executeWithRetry(_ endpoint: Endpoint) async throws -> Data {
        do {
            return try await performRequest(endpoint, forceTokenRefresh: false)
        } catch APIError.unauthorized where endpoint.requiresAuth {
            // Refresh Firebase token once and retry
            return try await performRequest(endpoint, forceTokenRefresh: true)
        }
    }

    private func performRequest(_ endpoint: Endpoint, forceTokenRefresh: Bool) async throws -> Data {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        let normalizedPath = endpoint.path.hasPrefix("/") ? endpoint.path : "/\(endpoint.path)"
        components.path = (components.path == "/" ? "" : components.path) + normalizedPath
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method.rawValue
        urlRequest.timeoutInterval = AppConfig.requestTimeout
        urlRequest.httpBody = endpoint.body

        if let contentType = endpoint.contentType {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if endpoint.requiresAuth {
            let headers = try await authProvider.authHeaders(forceRefresh: forceTokenRefresh)
            for (key, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid HTTP response.")
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            let msg = APIError.parseServerMessage(from: data)
            throw APIError.unauthorized(msg)
        default:
            let msg = APIError.parseServerMessage(from: data)
            throw APIError.httpError(statusCode: http.statusCode, message: msg)
        }
    }
}
