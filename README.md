# SARKit — SearchAdsRadar iOS SDK

Lightweight iOS SDK for Apple Search Ads attribution, revenue tracking, and analytics. Zero dependencies. Built for [SearchAdsRadar](https://searchadsradar.com).

## Installation

Swift Package Manager:

```
https://github.com/appnest-tech/searchadsradar-ios-sdk.git
```

Two products are available:

| Product | Use in | Includes |
|---------|--------|----------|
| **SARKit** | Main app target | Attribution + StoreKit 2 transactions + sessions + custom events |
| **SARKitCore** | App extensions (keyboard, widget) | Sessions + custom events only |

> Always use **SARKitCore** for app extensions. Using SARKit in an extension will crash due to StoreKit/AdServices sandbox restrictions.

## Quick Start

### Main App

```swift
import SARKit

// At app launch (before user identification):
SARKit.configure(apiKey: "YOUR_API_KEY")

// When user identity is known (e.g., after login/registration):
SARKit.identify("user_id")

// Track custom events:
SARKit.track("paywall_shown", properties: ["source": "onboarding"])

// On logout:
SARKit.reset()
```

### App Extensions

```swift
import SARKitCore

SARKitCore.configure(apiKey: "YOUR_API_KEY")
SARKitCore.identify("user_id")
SARKitCore.track("keyboard_opened")
```

## Identity

The SDK generates an anonymous ID on first launch (`sar_xxxx`), persisted in UserDefaults. This ID is included in every event, enabling tracking before user identification.

When `identify()` is called, subsequent events include both the anonymous ID and user ID. Your server can retroactively link pre-identification events.

```
Before identify():  { anonymousID: "sar_abc123", userID: null }
After identify():   { anonymousID: "sar_abc123", userID: "USER_42" }
```

## What It Captures

**Automatically (main app):**
- Apple Search Ads attribution token (first launch, retries on failure)
- StoreKit 2 transactions — purchases, renewals, refunds (iOS 16+)
- App sessions with retention metrics

**Automatically (extensions):**
- Sessions with retention metrics

**Manually:**
- Custom events via `track()`

## API

### `configure(apiKey:serverURL:debug:)`

Initialize the SDK. Call once at app launch.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `apiKey` | `String` | Yes | Your API key from SearchAdsRadar |
| `serverURL` | `String?` | No | Override server URL (defaults to production) |
| `debug` | `Bool` | No | Enable `[SARKit]` console logging (default: false) |

### `identify(_ userId:)`

Link this device to your server-side user ID. Call when the user's identity is known. Can be called multiple times (e.g., on each app launch after login).

### `track(_ name:properties:)`

Send a custom event with optional key-value properties.

### `reset()`

Clear user identity and flush pending events. Call on logout.

## Offline Support

Events are queued locally when the network is unavailable:
- Automatic retry on next app foreground
- Queue persisted across app restarts
- Max 200 events queued (oldest dropped when full)
- Events older than 7 days are discarded
- Backoff when server is unreachable

The SDK never blocks the main thread and never crashes if the server is down.

## Session Tracking

Sessions follow the industry standard (Amplitude, Firebase):
- New session on cold launch or after 30 seconds in background
- Quick foreground/background within 30s = same session
- Tracks: session count, retention day, days since last session

## Privacy

- **No IDFA** — uses IDFV (vendor identifier) and SDK-generated anonymous ID
- **No ATT prompt** required
- **Zero dependencies** — pure Apple frameworks
- **No PII collected**
- Includes Apple-required **Privacy Manifest** (PrivacyInfo.xcprivacy)

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15+

## License

MIT License. Copyright AppNest Technologies.
