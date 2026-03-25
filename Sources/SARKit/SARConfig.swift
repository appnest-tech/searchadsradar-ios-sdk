import Foundation

/// Configuration for the SARKit SDK.
public struct SARConfig {
    /// Default server URL for SearchAdsRadar.
    static let defaultServerURL = URL(string: "https://searchadsradar.com")!

    /// The API key that identifies your app. Get it from your SearchAdsRadar dashboard.
    public let apiKey: String

    /// The server URL. Defaults to SearchAdsRadar production.
    public let serverURL: URL

    /// Enable verbose logging for debugging. Default: false.
    public var debug: Bool

    public init(apiKey: String, serverURL: String? = nil, debug: Bool = false) {
        self.apiKey = apiKey
        self.debug = debug

        if let urlString = serverURL {
            guard let url = URL(string: urlString) else {
                fatalError("[SARKit] Invalid server URL: \(urlString)")
            }
            self.serverURL = url
        } else {
            self.serverURL = Self.defaultServerURL
        }
    }
}
