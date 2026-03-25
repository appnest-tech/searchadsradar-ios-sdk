import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Tracks app sessions and retention days.
/// Sends a session event on each app foreground with retention metadata.
final class SARSession {
    private let client: SARClient
    private let identity: SARIdentity
    private let userIDProvider: () -> String?

    private let firstLaunchKey = "com.searchadsradar.sarkit.first_launch"
    private let sessionCountKey = "com.searchadsradar.sarkit.session_count"
    private let lastSessionKey = "com.searchadsradar.sarkit.last_session"

    init(client: SARClient, identity: SARIdentity, userIDProvider: @escaping () -> String?) {
        self.client = client
        self.identity = identity
        self.userIDProvider = userIDProvider
    }

    /// Call on app launch / foreground. Tracks the session and sends an event.
    func trackSession() {
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

        // Session count
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

        let event = SAREvent(
            type: .session,
            deviceID: identity.deviceID,
            userID: userIDProvider(),
            timestamp: now,
            sdkVersion: SARKit.sdkVersion,
            device: identity.deviceInfo,
            data: [
                "sessionCount": AnyCodable(sessionCount),
                "retentionDay": AnyCodable(retentionDay),
                "firstLaunch": AnyCodable(firstLaunch.ISO8601Format()),
                "isFirstSession": AnyCodable(sessionCount == 1),
                "daysSinceLastSession": AnyCodable(daysSinceLastSession as Any),
            ]
        )
        client.send(event)
        SARLog.info("Session #\(sessionCount), retention day \(retentionDay)")
    }

    /// Register for foreground notifications to auto-track sessions.
    func startObserving() {
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.trackSession()
        }
        #endif

        // Track the initial session
        trackSession()
    }
}
