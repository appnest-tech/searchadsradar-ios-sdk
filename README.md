# SARKit — SearchAdsRadar iOS SDK

Lightweight iOS SDK for Apple Search Ads attribution, StoreKit 2 transaction tracking, session analytics, and custom events. Built for SearchAdsRadar's autonomous ad optimization agent.

## Installation

Add via Swift Package Manager:

```
https://github.com/appnest-tech/searchadsradar-ios-sdk.git
```

**Two products available:**

| Product | Use in | What it includes |
|---------|--------|-----------------|
| **SARKit** | Main app target | Attribution + StoreKit 2 + sessions + custom events |
| **SARKitCore** | App extensions (keyboard, widget, etc.) | Sessions + custom events only (no StoreKit, no AdServices) |

> Extensions cannot load StoreKit or AdServices frameworks — using `SARKit` in an extension will crash. Always use `SARKitCore` for extensions.

## Quick Start

### Main App

```swift
import SARKit

// In AppDelegate or startup:
SARKit.configure(apiKey: "sar_live_xxxxx")

// After user is identified (e.g., after RevenueCat login):
SARKit.identify("USER_HASH")

// Optional: track custom events
SARKit.track("paywall_shown", properties: ["source": "onboarding"])
```

### Keyboard Extension (or any extension)

```swift
import SARKitCore

// In viewDidLoad:
SARKitCore.configure(apiKey: "sar_live_xxxxx")
SARKitCore.identify("USER_HASH")

// Track extension usage:
SARKitCore.track("keyboard_opened", properties: ["appearanceCount": 15])
```

### That's it. The SDK automatically captures:
- **AdServices attribution token** (first launch, main app only)
- **StoreKit 2 transactions** — purchases, renewals, refunds, expirations (main app only)
- **Sessions** — count, retention day, days since last session
- **Device context** — model, OS, locale, timezone, app version, build number
- **Bundle ID** — distinguishes main app from extensions

## API Reference

### `configure(apiKey:serverURL:debug:)`

Initialize the SDK. Call once at app launch.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `apiKey` | `String` | Yes | — | Your SearchAdsRadar API key. Identifies your app. |
| `serverURL` | `String?` | No | `https://searchadsradar.com` | Override for self-hosted or testing. |
| `debug` | `Bool` | No | `false` | Enable `[SARKit]` console logging. |

### `identify(_ userId:)`

Link this device to your server-side user ID (e.g., RevenueCat app_user_id). Call after the user is identified. All subsequent events include this ID.

### `track(_ name:properties:)`

Send a custom event. Stored in `sdk_custom_events` table with queryable columns.

```swift
SARKit.track("onboarding_complete", properties: [
    "step": 5,
    "duration": 42.5,
    "skipped": false
])
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    iOS Device                           │
│                                                         │
│  ┌──────────────────────┐  ┌─────────────────────────┐  │
│  │     Main App         │  │   Keyboard Extension    │  │
│  │  import SARKit       │  │  import SARKitCore      │  │
│  │                      │  │                         │  │
│  │  - Attribution token │  │  - Sessions             │  │
│  │  - StoreKit 2 txns   │  │  - Custom events        │  │
│  │  - Sessions          │  │                         │  │
│  │  - Custom events     │  │                         │  │
│  └──────────┬───────────┘  └───────────┬─────────────┘  │
│             │                          │                │
│             └──────────┬───────────────┘                │
│                        │ POST /api/sdk/events           │
│                        │ Header: x-api-key              │
└────────────────────────┼────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  SearchAdsRadar      │
              │  Server              │
              │                      │
              │  sdk_events_raw      │  ← audit log (all events)
              │  sdk_attributions    │  ← AdServices tokens + Apple API response
              │  sdk_transactions    │  ← StoreKit 2 purchases
              │  sdk_sessions        │  ← app sessions + retention
              │  sdk_custom_events   │  ← track() events
              │                      │
              │  Resolution cron:    │
              │  token → Apple API   │
              │  IDs → campaign names│
              │  → rc_asa_details    │
              └──────────────────────┘
```

## What Gets Sent

### Event Payload (JSON)

```json
{
  "type": "session",
  "bundleID": "co.appnest.ios.aisland.keyboard",
  "deviceID": "FD70E1E7-98B7-4833-A487-766F9F26F129",
  "userID": "OFXP9RPX",
  "timestamp": "2026-03-25T16:45:00Z",
  "sdkVersion": "2.0.8",
  "device": {
    "model": "iPhone17,2",
    "os": "26.4.0",
    "locale": "en_US",
    "timezone": "Asia/Tehran",
    "appVersion": "4.0",
    "buildNumber": "4006"
  },
  "data": { ... }
}
```

### Event Types

| Type | Trigger | Data |
|------|---------|------|
| `attribution` | First launch (once per install) | `token` — raw AdServices attribution token |
| `transaction` | Every purchase/renewal/refund | `transactionID`, `productID`, `price`, `currency`, `jwsPayload`, `storefront`, `environment` |
| `session` | App foreground (after 30s background) | `sessionCount`, `retentionDay`, `firstLaunch`, `daysSinceLastSession` |
| Custom | `SARKit.track()` call | `eventName`, custom `properties` |

### Session Counting

Sessions follow the industry standard (Amplitude, Firebase):
- New session starts on **cold launch** or after **30 seconds** in background
- Quick foreground/background cycles within 30s = same session
- Session count only increments on new sessions

## Authentication

The SDK sends the API key in the `x-api-key` HTTP header. Each API key is tied to one app — the server resolves the account and app from the key. No bundle ID or app ID needed in the payload.

Keys are generated per-app on the SearchAdsRadar server and stored in the `apps.sdk_api_key` column.

## Offline Resilience

Events that fail to send (network offline, timeout) are queued in `UserDefaults` and automatically flushed on the next app foreground. The server handles duplicates via `ON CONFLICT` upserts.

## Privacy

- **IDFV only** — no IDFA, no ATT prompt required
- **Zero third-party dependencies** — pure Apple frameworks
- **No PII collected** — device model, OS, locale (no name, email, phone)
- iOS 16+ required (for StoreKit 2 price/currency APIs)

## Server-Side Tables

| Table | Purpose |
|-------|---------|
| `sdk_events_raw` | Raw JSON audit log of every event received |
| `sdk_attributions` | AdServices tokens + Apple API responses + resolved campaign/keyword IDs |
| `sdk_transactions` | Parsed StoreKit 2 transactions (price, currency, product, JWS) |
| `sdk_sessions` | Session count, retention day, first launch, device info |
| `sdk_custom_events` | Custom `track()` events with queryable `event_name` and `properties` (JSONB) |
| `rc_asa_details` | Final resolved attribution (campaign name, keyword, ad group) — single source of truth |

## Attribution Resolution Pipeline

```
1. SDK captures AdServices token on first launch
2. Server stores token in sdk_attributions (status: pending)
3. Resolution cron (every 10 min):
   Phase 1: POST token to https://api-adservices.apple.com/api/v1/
            → Apple returns: campaignId, adGroupId, keywordId, country
            → Store in sdk_attributions (status: resolved_ids)
   Phase 2: Resolve IDs → names via asa_*_daily_facts tables
            → Upsert into rc_asa_details (source: sdk)
4. Rate limited at 5 requests/second to avoid Apple API pressure
```

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15+

## License

MIT License. Copyright AppNest Technologies.
