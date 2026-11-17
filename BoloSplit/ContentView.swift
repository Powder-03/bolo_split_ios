//
//  ContentView.swift
//  BoloSplit
//
//  Phase 0 bootstrap view: verifies connectivity to the Render backend (/health).
//

import SwiftUI

private struct HealthResponse: Codable {
    let status: String
    let service: String
    let environment: String
}

struct ContentView: View {
    @State private var statusText = "Checking backend..."
    @State private var detailText = AppConfig.baseURL.absoluteString
    @State private var isLoading = false
    @State private var isHealthy = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isHealthy ? "checkmark.circle.fill" : "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(isHealthy ? .green : .teal)

            Text("BoloSplit iOS")
                .font(.largeTitle.bold())

            VStack(spacing: 6) {
                Text(statusText)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Button {
                Task { await checkHealth() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isLoading ? "Connecting (may wake Render)..." : "Ping /health")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .disabled(isLoading)
        }
        .padding(24)
        .task {
            await checkHealth()
        }
    }

    private func checkHealth() async {
        isLoading = true
        isHealthy = false
        statusText = "Connecting to Render..."
        detailText = AppConfig.baseURL.appendingPathComponent("health").absoluteString

        var request = URLRequest(url: AppConfig.baseURL.appendingPathComponent("health"))
        request.timeoutInterval = AppConfig.requestTimeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                statusText = "Server returned an error"
                return
            }
            let decoded = try JSONDecoder().decode(HealthResponse.self, from: data)
            isHealthy = decoded.status.lowercased() == "healthy"
            statusText = "Backend: \(decoded.status.uppercased())"
            detailText = "\(decoded.service) • \(decoded.environment)"
        } catch {
            statusText = "Connection failed"
            detailText = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    ContentView()
}
