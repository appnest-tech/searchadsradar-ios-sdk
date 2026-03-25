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
| **SARKit** | Main app target | Attribution + transactions + sessions + custom events |
| **SARKitCore** | App extensions (keyboard, widget) | Sessions + custom events only |

> Always use **SARKitCore** for app extensions. Using SARKit in an extension will crash due to StoreKit/AdServices sandbox restrictions.

## Quick Start

### Main App

```swift
import SARKit

// At app launch:
SARKit.configure(apiKey: "YOUR_API_KEY")

// After user is identified:
SARKit.identify("user_id")

// Track custom events:
SARKit.track("paywall_shown", properties: ["source": "onboarding"])
```

### App Extensions

```swift
import SARKitCore

SARKitCore.configure(apiKey: "YOUR_API_KEY")
SARKitCore.identify("user_id")
SARKitCore.track("keyboard_opened")
```

## What It Captures

**Automatically (main app):**
- Apple Search Ads attribution (first launch)
- StoreKit 2 transactions — purchases, renewals, refunds
- App sessions with retention metrics

**Automatically (extensions):**
- Sessions with retention metrics

**Manually:**
- Custom events via `track()`

## API

### `configure(apiKey:serverURL:debug:)`

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `apiKey` | `String` | Yes | Your API key from SearchAdsRadar |
| `serverURL` | `String?` | No | Override server URL (defaults to production) |
| `debug` | `Bool` | No | Enable console logging (default: false) |

### `identify(_ userId:)`

Link this device to your server-side user ID. Call after authentication.

### `track(_ name:properties:)`

Send a custom event with optional properties.

## Offline Support

Events are queued locally when the network is unavailable:
- Automatic retry on next app foreground
- Queue persisted across app restarts
- Max 200 events queued (oldest dropped when full)
- Events older than 7 days are discarded
- Backoff when server is unreachable

The SDK never blocks the main thread and never crashes if the server is down.

## Session Tracking

Sessions follow the industry standard:
- New session on cold launch or after 30 seconds in background
- Quick foreground/background within 30s = same session
- Tracks: session count, retention day, days since last session

## Privacy

- **IDFV only** — no IDFA, no ATT prompt
- **Zero dependencies** — pure Apple frameworks
- **No PII collected**
- iOS 16+ required

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15+

## License

MIT License. Copyright AppNest Technologies.
