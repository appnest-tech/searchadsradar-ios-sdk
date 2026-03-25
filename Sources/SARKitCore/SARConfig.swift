import Foundation

/// Configuration for the SARKit SDK.
public struct SARConfig {
    /// Default server URL for SearchAdsRadar.
    // swiftlint:disable:next force_unwrapping
    static let defaultServerURL = URL(string: "https://searchadsradar.com")!

    /// The API key that identifies your app.
    public let apiKey: String

    /// The server URL. Defaults to SearchAdsRadar production.
    public let serverURL: URL

    /// Enable verbose logging for debugging. Default: false.
    public var debug: Bool

    public init(apiKey: String, serverURL: String? = nil, debug: Bool = false) {
        self.apiKey = apiKey
        self.debug = debug

        if let urlString = serverURL, let url = URL(string: urlString) {
            self.serverURL = url
        } else {
            if serverURL != nil {
                SARLog.error("Invalid server URL, using default")
            }
            self.serverURL = Self.defaultServerURL
        }
    }
}
