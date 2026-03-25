import Foundation
@_exported import SARKitCore

/// SARKit — full SDK with attribution + StoreKit transactions + sessions.
/// Use this in your main app target. For extensions, use `SARKitCore`.
public final class SARKit {
    public static let sdkVersion = "2.1.0"

    private static var attribution: SARAttribution?
    private static var transactions: SARTransactions?

    /// Configure the full SDK. Call once in your main app.
    ///
    /// - Parameters:
    ///   - apiKey: Your SearchAdsRadar API key.
    ///   - userId: Optional user ID to set before any events fire.
    ///   - serverURL: Override server URL (for testing).
    ///   - debug: Enable console logging.
    public static func configure(
        apiKey: String,
        serverURL: String? = nil,
        debug: Bool = false
    ) {
        SARKitCore.configure(apiKey: apiKey, serverURL: serverURL, debug: debug)

        guard let core = SARKitCore.shared else { return }

        // Start attribution (main app only)
        let userIDProvider: () -> String? = { core.userIDBox.value }
        let attr = SARAttribution(client: core.client, identity: core.identity, userIDProvider: userIDProvider)
        attr.captureIfNeeded()
        attribution = attr

        // Start StoreKit transaction listener (main app only)
        let tx = SARTransactions(client: core.client, identity: core.identity, userIDProvider: userIDProvider)
        tx.startListening()
        transactions = tx
    }

    /// Link this device to a server-side user ID.
    public static func identify(_ userId: String) {
        SARKitCore.identify(userId)
    }

    /// Clear user identity and reset state. Call on logout.
    public static func reset() {
        SARKitCore.reset()
    }

    /// Track a custom event.
    public static func track(_ name: String, properties: [String: Any] = [:]) {
        SARKitCore.track(name, properties: properties)
    }
}
