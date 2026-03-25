import Foundation

/// Configuration for the SARKit SDK.
public struct SARConfig {
    /// The base URL of the SearchAdsRadar agent (e.g., "https://my-agent.searchadsradar.com").
    public let agentURL: URL

    /// The app's bundle identifier (e.g., "com.example.myapp").
    public let appID: String

    /// Enable verbose logging for debugging. Default: false.
    public var debug: Bool

    /// Server-side user ID (e.g., RevenueCat app_user_id). Set via SARKit.identify().
    public var userID: String?

    public init(agentURL: String, appID: String, debug: Bool = false) {
        guard let url = URL(string: agentURL) else {
            fatalError("[SARKit] Invalid agent URL: \(agentURL)")
        }
        self.agentURL = url
        self.appID = appID
        self.debug = debug
        self.userID = nil
    }
}
