import Foundation

/// HTTP client that sends events to the SearchAdsRadar agent.
/// Queues events when offline and flushes when possible.
final class SARClient: @unchecked Sendable {
    private let agentURL: URL
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

    init(agentURL: URL) {
        self.agentURL = agentURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        loadPendingEvents()
    }

    /// Send an event to the agent. Queues if send fails.
    func send(_ event: SAREvent) {
        queue.async { [weak self] in
            self?.doSend(event)
        }
    }

    private func doSend(_ event: SAREvent) {
        let endpoint = agentURL.appendingPathComponent("/api/sdk/events")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("SARKit/\(SARKit.sdkVersion)", forHTTPHeaderField: "User-Agent")

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
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if !success {
            pendingEvents.append(event)
            savePendingEvents()
        }
    }

    /// Retry sending any queued events. Called on app foreground.
    func flushPendingEvents() {
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
enum SARLog {
    nonisolated(unsafe) static var isEnabled = false

    static func info(_ message: String) {
        guard isEnabled else { return }
        print("[SARKit] \(message)")
    }

    static func error(_ message: String) {
        guard isEnabled else { return }
        print("[SARKit ERROR] \(message)")
    }
}
