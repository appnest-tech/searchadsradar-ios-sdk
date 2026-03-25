import Foundation

/// SARKitCore — lightweight SDK for sessions and custom events.
/// Safe for app extensions (no StoreKit, no AdServices).
///
/// Usage:
/// ```swift
/// import SARKitCore
///
/// SARKitCore.configure(apiKey: "sar_live_xxxxx", userId: "userHash")
/// SARKitCore.track("keyboard_opened")
/// ```
public final class SARKitCore {
    public static let sdkVersion = "2.1.0"

    public static var shared: SARKitCore?

    public let config: SARConfig
    public let client: SARClient
    public let identity: SARIdentity
    public let session: SARSession
    public let userIDBox = UserIDBox()

    public class UserIDBox {
        public var value: String?
    }

    init(config: SARConfig) {
        self.config = config
        self.client = SARClient(config: config)
        self.identity = SARIdentity()
        let box = self.userIDBox
        let userIDProvider: () -> String? = { box.value }
        self.session = SARSession(client: client, identity: identity, userIDProvider: userIDProvider)
    }

    // MARK: - Public API

    /// Configure and start the SDK. Call once at app launch.
    ///
    /// Events are tracked immediately with an anonymous ID.
    /// Call `identify()` when the user's server-side ID becomes available.
    public static func configure(
        apiKey: String,
        serverURL: String? = nil,
        debug: Bool = false
    ) {
        guard shared == nil else {
            SARLog.info("Already configured, ignoring duplicate call")
            return
        }

        let config = SARConfig(apiKey: apiKey, serverURL: serverURL, debug: debug)
        SARLog.isEnabled = config.debug
        SARLog.info("Configuring SARKitCore v\(sdkVersion)")
        SARLog.info("Anonymous ID: \(SARIdentity().anonymousID)")

        let instance = SARKitCore(config: config)
        shared = instance
        instance.start()
    }

    /// Link this device to a server-side user ID.
    /// If called after configure(), subsequent events will include this ID.
    /// For best results, pass userId in configure() instead.
    public static func identify(_ userId: String) {
        guard let instance = shared else {
            SARLog.error("Not configured. Call configure() first.")
            return
        }
        instance.userIDBox.value = userId
        SARLog.info("User identified: \(userId)")
    }

    /// Clear user identity and reset state. Call on logout.
    /// Pending events for the previous user are flushed before reset.
    public static func reset() {
        guard let instance = shared else { return }

        let previousUser = instance.userIDBox.value
        instance.userIDBox.value = nil

        // Flush pending events (they belong to the previous user)
        instance.client.flushPendingEvents()

        SARLog.info("Reset — cleared user \(previousUser ?? "anon")")
    }

    /// Track a custom event.
    public static func track(_ name: String, properties: [String: Any] = [:]) {
        guard let instance = shared else {
            SARLog.error("Not configured. Call configure() first.")
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
            anonymousID: instance.identity.anonymousID,
            deviceID: instance.identity.deviceID,
            userID: instance.userIDBox.value,
            device: instance.identity.deviceInfo,
            data: data
        )
        instance.client.send(event)
    }

    // MARK: - Private

    private func start() {
        client.flushPendingEvents()
        session.startObserving()
        SARLog.info("Started successfully")
    }
}
