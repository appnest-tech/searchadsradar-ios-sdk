import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects stable device identity and context.
final class SARIdentity: Sendable {

    /// IDFV — stable per vendor, always available, no permission needed.
    var deviceID: String {
        #if canImport(UIKit) && !os(watchOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        #else
        return "unknown"
        #endif
    }

    /// Device info for event context.
    var deviceInfo: SARDeviceInfo {
        SARDeviceInfo(
            model: deviceModel,
            os: osVersion,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
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
