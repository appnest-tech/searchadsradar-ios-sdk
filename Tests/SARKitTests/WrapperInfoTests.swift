import XCTest
@testable import SARKitCore

final class WrapperInfoTests: XCTestCase {
    override func tearDown() {
        SARKitCore.wrapperInfo = nil
        super.tearDown()
    }

    func testEffectiveVersionWithoutWrapperIsBareCoreVersion() {
        SARKitCore.wrapperInfo = nil
        XCTAssertEqual(SARKitCore.effectiveSDKVersion, SARKitCore.sdkVersion)
    }

    func testEffectiveVersionWithWrapperUsesPlusFormat() {
        SARKitCore.setWrapperInfo(platform: "flutter", version: "1.0.0")
        XCTAssertEqual(
            SARKitCore.effectiveSDKVersion,
            "flutter-1.0.0+sarkit-\(SARKitCore.sdkVersion)"
        )
    }

    func testEventCreateDefaultsToEffectiveVersion() {
        SARKitCore.setWrapperInfo(platform: "rn", version: "2.0.0")
        let event = SAREvent.create(
            type: .session,
            anonymousID: "anon",
            deviceID: "dev",
            userID: nil,
            device: SARDeviceInfo(
                model: "m", os: "o", locale: "l", timezone: "t",
                appVersion: "1", buildNumber: "1"
            ),
            data: [:]
        )
        XCTAssertEqual(event.sdkVersion, "rn-2.0.0+sarkit-\(SARKitCore.sdkVersion)")
    }
}
