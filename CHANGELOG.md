# Changelog

## 3.1.0 — 2026-08-17

Wrapper-enablement release. Required minimum for the Flutter/RN wrapper packages.

### Fixed
- **Observer mode:** SARKit no longer calls `transaction.finish()` on observed
  StoreKit transactions. Finishing is the host app's signal that it granted the
  entitlement; SARKit finishing first could race the app's own purchase
  handling (worst under Flutter/RN purchase plugins).
- `reset()` no longer stops the transaction listener — logout→login within one
  process keeps capturing purchases.

### Added
- `SARKitCore.setWrapperInfo(platform:version:)` +
  `SARKitCore.effectiveSDKVersion` — cross-platform wrappers identify
  themselves; events report e.g. `flutter-1.0.0+sarkit-3.1.0`.
- Client-minted `eventID` (UUID v4) on every event — activates server-side
  idempotent ingest (safe retries, no double-counting).
- macOS 13 platform floor in Package.swift so the package builds/tests on
  macOS hosts (no change for iOS consumers).

### Notes
- Pre-3.1.0 events queued offline still decode after upgrade (`eventID` is
  optional) and are accepted by the server as legacy (no dedup key).
