import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects stable device identity and context.
public final class SARIdentity: Sendable {

    private static let anonymousIDKey = "com.searchadsradar.sarkit.anonymous_id"

    /// SDK-generated anonymous ID. Persisted across sessions.
    /// Created on first launch, stable until app is deleted.
    public let anonymousID: String = {
        if let existing = UserDefaults.standard.string(forKey: anonymousIDKey) {
            return existing
        }
        let newID = "sar_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(24)
        UserDefaults.standard.set(String(newID), forKey: anonymousIDKey)
        return String(newID)
    }()

    /// IDFV — hardware device identifier, stable per vendor.
    public let deviceID: String = {
        #if canImport(UIKit) && !os(watchOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        #else
        return "unknown"
        #endif
    }()

    /// Device info for event context. All fields safe for app extensions.
    public var deviceInfo: SARDeviceInfo {
        let info = Bundle.main.infoDictionary
        return SARDeviceInfo(
            model: deviceModel,
            os: osVersion,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            appVersion: (info?["CFBundleShortVersionString"] as? String) ?? "unknown",
            buildNumber: (info?["CFBundleVersion"] as? String) ?? "unknown"
        )
    }

    private var deviceModel: String {
        // Use sysctlbyname instead of uname — safer in app extensions
        var size: Int = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    private var osVersion: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }
}
