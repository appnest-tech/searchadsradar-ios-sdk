import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects stable device identity and context.
public final class SARIdentity: Sendable {

    /// IDFV — stable per vendor, no permission needed.
    /// In keyboard extensions, UIDevice may not have IDFV — falls back to "unknown".
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
