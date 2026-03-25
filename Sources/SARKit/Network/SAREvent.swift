import Foundation

/// The event types that SARKit sends to the agent.
public enum SAREventType: String, Codable {
    case attribution
    case transaction
    case session
}

/// A single event payload sent to the SearchAdsRadar agent.
public struct SAREvent: Codable {
    let type: SAREventType
    let appID: String
    let deviceID: String
    let timestamp: Date
    let sdkVersion: String
    let device: SARDeviceInfo
    let data: [String: AnyCodable]
}

/// Device context sent with every event.
public struct SARDeviceInfo: Codable {
    let model: String
    let os: String
    let locale: String
    let timezone: String
    let appVersion: String
    let buildNumber: String
}

/// Type-erased Codable wrapper for heterogeneous event data.
public struct AnyCodable: Codable {
    let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let dict as [String: AnyCodable]:
            try container.encode(dict)
        case let array as [AnyCodable]:
            try container.encode(array)
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encode(String(describing: value))
        }
    }
}
