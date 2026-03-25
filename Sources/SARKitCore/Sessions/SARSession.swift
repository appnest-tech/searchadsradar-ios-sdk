import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Tracks app sessions and retention days.
///
/// Session counting follows the industry standard (Amplitude, Firebase):
/// - A new session starts when the app comes to foreground after being
///   backgrounded for longer than `sessionTimeout` (default 30 seconds).
/// - Multiple foreground/background cycles within the timeout are the same session.
/// - Cold launch always starts a new session.
/// - Session count increments only on new sessions.
public final class SARSession {
    private let client: SARClient
    private let identity: SARIdentity
    private let userIDProvider: () -> String?

    private let firstLaunchKey = "com.searchadsradar.sarkit.first_launch"
    private let sessionCountKey = "com.searchadsradar.sarkit.session_count"
    private let lastSessionKey = "com.searchadsradar.sarkit.last_session"

    /// Seconds the app must be backgrounded before a new session starts.
    private let sessionTimeout: TimeInterval = 30

    /// When the app last entered background (in-memory only).
    private var backgroundedAt: Date?

    /// Whether we've already sent the initial session for this cold launch.
    private var hasSentInitialSession = false

    public init(client: SARClient, identity: SARIdentity, userIDProvider: @escaping () -> String?) {
        self.client = client
        self.identity = identity
        self.userIDProvider = userIDProvider
    }

    /// Register for lifecycle notifications and track the initial (cold launch) session.
    public func startObserving() {
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onBackground()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onForeground()
        }
        #endif

        // Cold launch = always a new session
        startNewSession()
    }

    // MARK: - Lifecycle

    private func onBackground() {
        backgroundedAt = Date()
    }

    private func onForeground() {
        guard let bg = backgroundedAt else {
            // No background timestamp — app was never backgrounded, skip
            return
        }

        let elapsed = Date().timeIntervalSince(bg)
        backgroundedAt = nil

        if elapsed >= sessionTimeout {
            // App was backgrounded long enough — new session
            startNewSession()
        } else {
            SARLog.info("Resumed within \(Int(elapsed))s — same session")
        }
    }

    // MARK: - Session Tracking

    private func startNewSession() {
        let defaults = UserDefaults.standard
        let now = Date()

        // First launch tracking
        let firstLaunch: Date
        if let stored = defaults.object(forKey: firstLaunchKey) as? Date {
            firstLaunch = stored
        } else {
            firstLaunch = now
            defaults.set(now, forKey: firstLaunchKey)
        }

        // Increment session count
        let sessionCount = defaults.integer(forKey: sessionCountKey) + 1
        defaults.set(sessionCount, forKey: sessionCountKey)

        // Days since install
        let retentionDay = Calendar.current.dateComponents([.day], from: firstLaunch, to: now).day ?? 0

        // Days since last session
        let lastSession = defaults.object(forKey: lastSessionKey) as? Date
        let daysSinceLastSession: Int?
        if let last = lastSession {
            daysSinceLastSession = Calendar.current.dateComponents([.day], from: last, to: now).day
        } else {
            daysSinceLastSession = nil
        }
        defaults.set(now, forKey: lastSessionKey)

        let isFirst = sessionCount == 1

        let event = SAREvent.create(
            type: .session,
            deviceID: identity.deviceID,
            userID: userIDProvider(),
            timestamp: now,
            device: identity.deviceInfo,
            data: [
                "sessionCount": AnyCodable(sessionCount),
                "retentionDay": AnyCodable(retentionDay),
                "firstLaunch": AnyCodable(firstLaunch.ISO8601Format()),
                "isFirstSession": AnyCodable(isFirst),
                "daysSinceLastSession": AnyCodable(daysSinceLastSession as Any),
            ]
        )
        client.send(event)
        hasSentInitialSession = true
        SARLog.info("Session #\(sessionCount), retention day \(retentionDay)\(isFirst ? " (first)" : "")")
    }
}
