import Foundation

/// HTTP client that sends events to the SearchAdsRadar server.
/// Sends API key in header for authentication. Queues events when offline.
public final class SARClient: @unchecked Sendable {
    private let config: SARConfig
    private let session: URLSession
    private let queue = DispatchQueue(label: "com.searchadsradar.sarkit.client")
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// Events waiting to be sent (persisted to UserDefaults for crash safety).
    private var pendingEvents: [SAREvent] = []
    private let storageKey = "com.searchadsradar.sarkit.pending_events"

    public init(config: SARConfig) {
        self.config = config
        let urlConfig = URLSessionConfiguration.default
        urlConfig.timeoutIntervalForRequest = 15
        urlConfig.waitsForConnectivity = true
        self.session = URLSession(configuration: urlConfig)
        loadPendingEvents()
    }

    /// Send an event to the server. Queues if send fails.
    public func send(_ event: SAREvent) {
        queue.async { [weak self] in
            self?.doSend(event)
        }
    }

    private func doSend(_ event: SAREvent) {
        let endpoint = config.serverURL.appendingPathComponent("api/sdk/events")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("SARKit/\(SARKitCore.sdkVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")

        do {
            request.httpBody = try encoder.encode(event)
        } catch {
            SARLog.error("Failed to encode event: \(error)")
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        let task = session.dataTask(with: request) { _, response, error in
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                success = true
            } else if let error = error {
                SARLog.error("Send failed: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse {
                SARLog.error("Send failed: HTTP \(http.statusCode)")
            }
            semaphore.signal()
        }
        task.resume()

        // Wait max 20 seconds — never block forever if server is down
        let result = semaphore.wait(timeout: .now() + 20)
        if result == .timedOut {
            task.cancel()
            SARLog.error("Send timed out — server may be down")
        }

        if !success {
            pendingEvents.append(event)
            savePendingEvents()
        }
    }

    /// Retry sending any queued events. Called on app foreground.
    public func flushPendingEvents() {
        queue.async { [weak self] in
            guard let self = self, !self.pendingEvents.isEmpty else { return }
            let events = self.pendingEvents
            self.pendingEvents.removeAll()
            self.savePendingEvents()
            for event in events {
                self.doSend(event)
            }
        }
    }

    // MARK: - Persistence

    private func savePendingEvents() {
        if let data = try? encoder.encode(pendingEvents) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadPendingEvents() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let events = try? decoder.decode([SAREvent].self, from: data) {
            pendingEvents = events
        }
    }
}

/// Minimal internal logger.
public enum SARLog {
    public nonisolated(unsafe) static var isEnabled = false

    public static func info(_ message: String) {
        guard isEnabled else { return }
        print("[SARKit] \(message)")
    }

    public static func error(_ message: String) {
        guard isEnabled else { return }
        print("[SARKit ERROR] \(message)")
    }
}
