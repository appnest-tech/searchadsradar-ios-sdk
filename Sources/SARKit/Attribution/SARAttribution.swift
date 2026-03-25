import Foundation
#if canImport(AdServices)
import AdServices
#endif

/// Captures the AdServices attribution token on first launch
/// and sends it to the SearchAdsRadar agent.
final class SARAttribution {
    private let client: SARClient
    private let identity: SARIdentity
    private let appID: String
    private let userIDProvider: () -> String?
    private let sentKey = "com.searchadsradar.sarkit.attribution_sent"

    init(client: SARClient, identity: SARIdentity, appID: String, userIDProvider: @escaping () -> String?) {
        self.client = client
        self.identity = identity
        self.appID = appID
        self.userIDProvider = userIDProvider
    }

    /// Capture and send attribution token. Only runs once per install.
    func captureIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: sentKey) else {
            SARLog.info("Attribution already captured, skipping")
            return
        }

        #if canImport(AdServices)
        do {
            let token = try AAAttribution.attributionToken()
            SARLog.info("Got attribution token (\(token.prefix(20))...)")

            let event = SAREvent(
                type: .attribution,
                appID: appID,
                deviceID: identity.deviceID,
                userID: userIDProvider(),
                timestamp: Date(),
                sdkVersion: SARKit.sdkVersion,
                device: identity.deviceInfo,
                data: [
                    "token": AnyCodable(token)
                ]
            )
            client.send(event)
            UserDefaults.standard.set(true, forKey: sentKey)
        } catch {
            SARLog.error("AdServices attribution failed: \(error.localizedDescription)")
            // Don't mark as sent — will retry next launch
        }
        #else
        SARLog.info("AdServices not available on this platform")
        #endif
    }
}
