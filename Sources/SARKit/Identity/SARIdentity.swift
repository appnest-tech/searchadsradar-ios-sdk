import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects stable device identity and context.
final class SARIdentity: Sendable {

    /// IDFV — stable per vendor, no permission needed.
    /// In keyboard extensions, UIDevice may not have IDFV — falls back to "unknown".
    let deviceID: String = {
        #if canImport(UIKit) && !os(watchOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        #else
        return "unknown"
        #endif
    }()

    /// Device info for event context. All fields safe for app extensions.
    var deviceInfo: SARDeviceInfo {
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
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                guard $0.pointee != 0 else { return nil as String? }
                return String(cString: $0)
            }
        }
        return machine ?? "unknown"
    }

    private var osVersion: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }
}
