//
//  AppConfig.swift
//  BoloSplit
//
//  Environment & API base URL configuration.
//

import Foundation

enum AppConfig {
    /// Live Render backend URL (update if your Render service URL differs).
    static let productionBaseURL = URL(string: "https://bolosplit.onrender.com")!

    /// Local FastAPI server URL for simulator testing against localhost.
    static let localBaseURL = URL(string: "http://127.0.0.1:8000")!

    /// Active base URL used by networking calls.
    static var baseURL: URL {
        // Switch to `localBaseURL` if testing against local uvicorn.
        productionBaseURL
    }

    /// Network timeout in seconds (60s accommodates Render free-tier cold starts & Gemini AI latency).
    static let requestTimeout: TimeInterval = 60
}
