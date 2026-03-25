import Foundation

/// SearchAdsRadar SDK — lightweight analytics for ASA attribution and revenue tracking.
///
/// Usage:
/// ```swift
/// import SARKit
///
/// SARKit.configure(agentURL: "https://my-agent.searchadsradar.com", appID: "com.example.app")
/// ```
///
/// That's it. The SDK automatically captures:
/// - AdServices attribution token (first launch only)
/// - StoreKit 2 transactions (purchases, renewals, refunds)
/// - App sessions and retention days
public final class SARKit {
    public static let sdkVersion = "1.0.0"

    private static var shared: SARKit?

    private let config: SARConfig
    private let client: SARClient
    private let identity: SARIdentity
    private let attribution: SARAttribution
    private let transactions: SARTransactions
    private let session: SARSession

    private init(config: SARConfig) {
        self.config = config
        self.client = SARClient(agentURL: config.agentURL)
        self.identity = SARIdentity()
        self.attribution = SARAttribution(client: client, identity: identity, appID: config.appID)
        self.transactions = SARTransactions(client: client, identity: identity, appID: config.appID)
        self.session = SARSession(client: client, identity: identity, appID: config.appID)
    }

    // MARK: - Public API

    /// Configure and start the SDK. Call once in your AppDelegate or App init.
    ///
    /// - Parameters:
    ///   - agentURL: The base URL of your SearchAdsRadar agent.
    ///   - appID: Your app's bundle identifier.
    ///   - debug: Enable verbose logging. Default: false.
    public static func configure(agentURL: String, appID: String, debug: Bool = false) {
        guard shared == nil else {
            SARLog.info("Already configured, ignoring duplicate call")
            return
        }

        let config = SARConfig(agentURL: agentURL, appID: appID, debug: debug)
        SARLog.isEnabled = config.debug
        SARLog.info("Configuring SARKit v\(sdkVersion)")
        SARLog.info("Agent: \(config.agentURL)")
        SARLog.info("App: \(config.appID)")

        let instance = SARKit(config: config)
        shared = instance
        instance.start()
    }

    /// Manually send a custom event to the agent.
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

        let event = SAREvent(
            type: .session,
            appID: instance.config.appID,
            deviceID: instance.identity.deviceID,
            timestamp: Date(),
            sdkVersion: sdkVersion,
            device: instance.identity.deviceInfo,
            data: data
        )
        instance.client.send(event)
    }

    // MARK: - Private

    private func start() {
        // 1. Flush any events queued from previous sessions
        client.flushPendingEvents()

        // 2. Capture attribution (only on first launch)
        attribution.captureIfNeeded()

        // 3. Start transaction listener
        transactions.startListening()

        // 4. Start session tracking
        session.startObserving()

        SARLog.info("SARKit started successfully")
    }
}
