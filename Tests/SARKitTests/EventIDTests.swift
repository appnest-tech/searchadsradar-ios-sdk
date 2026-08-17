import XCTest
@testable import SARKitCore

final class EventIDTests: XCTestCase {
    private func makeEvent() -> SAREvent {
        SAREvent.create(
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
    }

    func testEventIDIsMintedAndUniquePerEvent() {
        let a = makeEvent()
        let b = makeEvent()
        XCTAssertNotNil(a.eventID)
        XCTAssertFalse(a.eventID!.isEmpty)
        XCTAssertNotEqual(a.eventID, b.eventID)
    }

    func testEventIDEncodesToJSONKey() throws {
        let event = makeEvent()
        let data = try JSONEncoder().encode(event)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"eventID\""))
        XCTAssertTrue(json.contains(event.eventID!))
    }

    func testLegacyEventWithoutEventIDStillDecodes() throws {
        // Shape of a pre-3.1.0 queued event: no eventID field.
        let legacy = """
        {"type":"session","anonymousID":"anon","bundleID":"b","deviceID":"dev",
         "userID":null,"timestamp":"2026-08-17T00:00:00Z","sdkVersion":"3.0.0",
         "device":{"model":"m","os":"o","locale":"l","timezone":"t",
                   "appVersion":"1","buildNumber":"1"},
         "data":{}}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(SAREvent.self, from: legacy)
        XCTAssertNil(event.eventID)
    }
}
