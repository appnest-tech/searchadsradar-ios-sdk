import Foundation

/// HTTP client that sends events to the SearchAdsRadar server.
/// Queues failed events to UserDefaults, retries on next foreground.
/// Max 200 queued events, drops oldest when full. 7-day TTL on queued events.
public final class SARClient: @unchecked Sendable {
    private let config: SARConfig
    private let session: URLSession
    private let queue = DispatchQueue(label: "com.searchadsradar.sarkit.client")
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private var pendingEvents: [SAREvent] = []
    private let storageKey = "com.searchadsradar.sarkit.pending_events"

    /// Max events to keep in offline queue. Oldest dropped when full.
    private let maxQueueSize = 200

    /// Events older than this are dropped on flush (stale data isn't useful).
    private let maxEventAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    /// Consecutive failures — used for backoff on flush.
    private var consecutiveFailures = 0

    public init(config: SARConfig) {
        self.config = config
        let urlConfig = URLSessionConfiguration.default
        urlConfig.timeoutIntervalForRequest = 15
        urlConfig.waitsForConnectivity = false // don't wait — fail fast, queue
        self.session = URLSession(configuration: urlConfig)
        loadPendingEvents()
    }

    /// Send an event. Non-blocking — dispatches to background queue.
    /// If send fails, event is queued and retried on next foreground.
    public func send(_ event: SAREvent) {
        queue.async { [weak self] in
            self?.doSend(event)
        }
    }

    /// Retry queued events. Called on app foreground.
    /// Drops stale events (>7 days old), backs off if server is down.
    public func flushPendingEvents() {
        queue.async { [weak self] in
            guard let self = self, !self.pendingEvents.isEmpty else { return }

            // Drop events older than 7 days
            let cutoff = Date().addingTimeInterval(-self.maxEventAge)
            let fresh = self.pendingEvents.filter { $0.timestamp > cutoff }
            let dropped = self.pendingEvents.count - fresh.count
            if dropped > 0 {
                SARLog.info("Dropped \(dropped) stale events (>7 days old)")
            }

            guard !fresh.isEmpty else {
                self.pendingEvents.removeAll()
                self.savePendingEvents()
                return
            }

            // Backoff: if we failed recently, only try one event as a probe
            let batch: [SAREvent]
            if self.consecutiveFailures >= 3 {
                batch = [fresh[0]]
                SARLog.info("Backoff: probing with 1 event (\(self.consecutiveFailures) consecutive failures)")
            } else {
                batch = fresh
            }

            self.pendingEvents.removeAll()
            self.savePendingEvents()

            var stillFailing = false
            for event in batch {
                if stillFailing {
                    // Server is down — re-queue remaining without trying
                    self.enqueue(event)
                } else {
                    self.doSend(event)
                    // If it ended up back in queue, server is still down
                    if self.pendingEvents.last?.timestamp == event.timestamp {
                        stillFailing = true
                        // Re-queue the rest of the batch we haven't tried
                    }
                }
            }

            // If we were in backoff mode and the probe succeeded, re-queue the rest
            if !stillFailing && batch.count < fresh.count {
                for event in fresh.dropFirst() {
                    self.doSend(event)
                }
                self.consecutiveFailures = 0
            }
        }
    }

    // MARK: - Private

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

        let result = semaphore.wait(timeout: .now() + 20)
        if result == .timedOut {
            task.cancel()
            SARLog.error("Send timed out")
        }

        if success {
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
            enqueue(event)
        }
    }

    private func enqueue(_ event: SAREvent) {
        pendingEvents.append(event)

        // Drop oldest if over limit
        if pendingEvents.count > maxQueueSize {
            let overflow = pendingEvents.count - maxQueueSize
            pendingEvents.removeFirst(overflow)
            SARLog.info("Queue full — dropped \(overflow) oldest events")
        }

        savePendingEvents()
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
            if !events.isEmpty {
                SARLog.info("Loaded \(events.count) pending events from previous session")
            }
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
