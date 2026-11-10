# Sawar (iOS)

Native SwiftUI app for WearFit-compatible watches. Protocol notes: `../research/protocol.md`.

## Layout

- `Packages/WatchCore` — protocol (framing, commands, decoders, drivers). Foundation only. `swift test`.
- `App/` — SwiftUI app. BLE lives only in `App/BLE/BLECentral.swift`.
- `AppTests/` — app unit tests.
- `project.yml` — XcodeGen spec (the `.xcodeproj` is generated, not committed).
- `l10n/` — Arabic translations (`ar.json`) and the catalog builder.

## Build (macOS with Xcode 15.4+)

```bash
brew install xcodegen
cd ios && python3 -I l10n/build_strings.py && xcodegen generate
open Sawar.xcodeproj
```

On every push, GitHub Actions (`.github/workflows/ios.yml`) runs the l10n check, `swift test`, and an
unsigned simulator build + tests.

## Install on an iPhone (needs the owner's Apple Developer account)

1. Set `DEVELOPMENT_TEAM` in `project.yml` (or in Xcode), and a bundle id you own instead of `app.sawar.ios`.
2. Enable the HealthKit capability for that bundle id in the Apple Developer portal.
3. Build from Xcode to a connected iPhone, or add a signed CI job (Xcode Cloud / Codemagic / Actions
   with your certificate and provisioning profile stored as secrets) and upload to TestFlight.

## Status

Nothing here has been compiled or run yet. See `../replica/features.csv` for the honest status of every feature.
