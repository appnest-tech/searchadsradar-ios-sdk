import Foundation

/// SearchAdsRadar SDK — lightweight analytics for ASA attribution and revenue tracking.
///
/// Usage:
/// ```swift
/// import SARKit
///
/// SARKit.configure(apiKey: "sar_live_xxxxx")
/// ```
///
/// That's it. The SDK automatically captures:
/// - AdServices attribution token (first launch only)
/// - StoreKit 2 transactions (purchases, renewals, refunds)
/// - App sessions and retention days
public final class SARKit {
    public static let sdkVersion = "2.0.0"

    private static var shared: SARKit?

    private let config: SARConfig
    private let client: SARClient
    private let identity: SARIdentity
    private let attribution: SARAttribution?
    private let transactions: SARTransactions?
    private let session: SARSession
    private let userIDBox = UserIDBox()

    /// Mutable box for userID — shared with subsystems via closure.
    private class UserIDBox {
        var value: String?
    }

    private init(config: SARConfig) {
        self.config = config
        self.client = SARClient(config: config)
        self.identity = SARIdentity()
        let box = self.userIDBox
        let userIDProvider: () -> String? = { box.value }

        // In app extensions, don't create attribution or transaction objects at all.
        // StoreKit framework loading alone can crash in extension sandboxes.
        if Self.isAppExtension {
            self.attribution = nil
            self.transactions = nil
        } else {
            self.attribution = SARAttribution(client: client, identity: identity, userIDProvider: userIDProvider)
            self.transactions = SARTransactions(client: client, identity: identity, userIDProvider: userIDProvider)
        }

        self.session = SARSession(client: client, identity: identity, userIDProvider: userIDProvider)
    }

    // MARK: - Public API

    /// Configure and start the SDK. Call once in your AppDelegate or App init.
    ///
    /// - Parameters:
    ///   - apiKey: Your SearchAdsRadar API key. Identifies your app.
    ///   - serverURL: Override the server URL (for testing or self-hosted). Defaults to SearchAdsRadar production.
    ///   - debug: Enable verbose logging. Default: false.
    public static func configure(apiKey: String, serverURL: String? = nil, debug: Bool = false) {
        guard shared == nil else {
            SARLog.info("Already configured, ignoring duplicate call")
            return
        }

        let config = SARConfig(apiKey: apiKey, serverURL: serverURL, debug: debug)
        SARLog.isEnabled = config.debug
        SARLog.info("Configuring SARKit v\(sdkVersion)")
        SARLog.info("Server: \(config.serverURL)")

        let instance = SARKit(config: config)
        shared = instance
        instance.start()
    }

    /// Link this device to a server-side user ID (e.g., RevenueCat app_user_id).
    ///
    /// Call after the user is identified in your system. All subsequent events
    /// will include this user ID alongside the device ID (IDFV).
    ///
    /// - Parameter userId: Your server-side user identifier.
    public static func identify(_ userId: String) {
        guard let instance = shared else {
            SARLog.error("SARKit not configured. Call SARKit.configure() first.")
            return
        }
        instance.userIDBox.value = userId
        SARLog.info("User identified: \(userId)")
    }

    /// Manually send a custom event.
    ///
    /// Use this for tracking app-specific events like onboarding completion,
    /// paywall views, or feature usage — segmented by acquisition channel.
    ///
    /// - Parameters:
    ///   - name: Event name (e.g., "paywall_shown", "onboarding_complete").
    ///   - properties: Optional key-value pairs.
    public static func track(_ name: String, properties: [String: Any] = [:]) {
        guard let instance = shared else {
            SARLog.error("SARKit not configured. Call SARKit.configure() first.")
            return
        }

        var data: [String: AnyCodable] = [
            "name": AnyCodable(name),
            "eventType": AnyCodable("custom")
        ]
        for (key, value) in properties {
            data[key] = AnyCodable(value)
        }

        let event = SAREvent.create(
            type: .session,
            deviceID: instance.identity.deviceID,
            userID: instance.userIDBox.value,
            device: instance.identity.deviceInfo,
            data: data
        )
        instance.client.send(event)
    }

    // MARK: - Private

    /// Whether we're running inside an app extension (keyboard, widget, etc.)
    private static var isAppExtension: Bool {
        Bundle.main.bundlePath.hasSuffix(".appex")
    }

    private func start() {
        // 1. Flush any events queued from previous sessions
        client.flushPendingEvents()

        // 2. Capture attribution (main app only)
        attribution?.captureIfNeeded()

        // 3. Start transaction listener (main app only)
        transactions?.startListening()

        if Self.isAppExtension {
            SARLog.info("Running in app extension — sessions and custom events only")
        }

        // 4. Start session tracking (works everywhere)
        session.startObserving()

        SARLog.info("SARKit started successfully")
    }
}
