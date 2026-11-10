# Architecture — new iPhone app for WearFit-compatible watches

Overrides the Replica defaults per `CLAUDE.md`: native iOS, no backend, no Expo.

## 1. Stack

| layer | choice | why |
|---|---|---|
| language / UI | Swift 5.9+, SwiftUI, iOS 17+ | native, needed for SwiftData + Observation |
| BLE | CoreBluetooth (app target), protocol logic in a pure-Swift package | protocol code testable without a phone |
| storage | SwiftData | local only; no account, no server |
| health | HealthKit (write device samples; read for display when allowed) | REQUIREMENTS §5 |
| charts | Swift Charts | native |
| photos | PhotosUI `PhotosPicker` | watch-face images |
| location | CoreLocation + MapKit | phone-led workouts, weather location |
| weather | WeatherKit (needs the user's Apple Developer account) | official API, no vendor server |
| contacts | Contacts / ContactsUI | contacts to watch |
| project | XcodeGen `ios/project.yml` | writable on Windows; `.xcodeproj` generated in CI |
| CI | GitHub Actions `macos-14`: xcodegen → `swift test` (WatchCore) → `xcodebuild build/test` (simulator) | there is no Mac |

## 2. Modules

```
ios/
  project.yml                     XcodeGen spec (app + tests, links the local package)
  Packages/WatchCore/             Swift package, Foundation only (no UIKit, no CoreBluetooth)
    Sources/WatchCore/
      Protocol/  Frame.swift (AB/EA framing), Reassembler.swift, CRC16.swift
      Commands/  Command encoders (one func per command, bytes from research/protocol.md)
      Decoding/  Decoders for replies (device info, summary, HR/SpO2/BP, sleep…)
      Model/     DeviceInfo, Capabilities, records (plain structs)
      Drivers/   WatchTransport, WatchDriver, WakeupDriver (shared), family drivers
    Tests/WatchCoreTests/          golden-byte tests for every encoder/decoder
  App/
    App/          app entry, root tabs, dependency container
    BLE/          BLETransport (CoreBluetooth), Scanner, connection + restoration
    Data/         SwiftData models, repositories, HealthKit bridge
    Features/     Today, Health, Workouts, Faces, Files, Device (settings), Onboarding, Debug
    Design/       tokens, components (from replica/design)
    Resources/    Localizable.xcstrings (en, ar), Info.plist, Assets
  AppTests/       view-model tests with a fake transport
```

## 3. Device layer

```swift
protocol WatchTransport: AnyObject {           // CoreBluetooth in the app, fakes in tests
  func write(_ data: Data, channel: Channel) async throws
  var incoming: AsyncStream<(Channel, Data)> { get }
}
protocol WatchDriver {
  var family: DeviceFamily { get }
  var capabilities: Capabilities { get }       // from device-info bits + probing, never assumed
  func perform(_ cmd: Command) async throws    // settings, find, measure…
  func sync() -> AsyncThrowingStream<Record, Error>
  func installFace(_ face: FacePayload) -> AsyncThrowingStream<TransferProgress, Error>
  func updateFirmware(_ file: URL, consent: FirmwareConsent) async throws   // gated
}
```

- `WakeupDriver` implements the shared AB/EA protocol (all families).
- `SiFliDriver`, `BluetrumDriver`, `NordicDriver`, `HiSiliconDriver` extend it for the family-specific
  parts (faces, firmware, logs). Every family-specific operation that is not confirmed throws
  `WatchError.notSupported(reason:)` — the UI shows the reason; no fake success.
- `DriverFactory.make(info:, services:)` picks the family from advertised/discovered services
  (SiFli base UUID, `FF12`, `FE59`) and device-info flags; unknown → `WakeupDriver` with generic paths.
- A watch-confirmed result is required before any "installed/sent" message (transfer ends only on
  the device's final ack).

## 4. Data model (SwiftData)

`DeviceRecord`, `HealthSample` (kind, start, end, value, value2, source = device | manual |
healthKit | estimate), `SleepSession` + `SleepStage`, `DaySummary`, `Workout` + route points,
`AlarmItem`, `ReminderSetting`, `WatchFaceItem`, `TransferJob`, `PacketLogEntry`. Times stored as
`Date` (UTC); day buckets computed in the user's calendar/time zone. Unique keys: (deviceId, kind,
start) for samples so re-syncs do not duplicate.

## 5. "API" (there is no server)

| flow | call |
|---|---|
| F01 connect | `Scanner.scan()` → `BLETransport.connect()` → `WakeupDriver.handshake()` (time, phone OS, device info, screen) |
| F02 sync | `driver.sync()` → repositories upsert → HealthKit export (if allowed) |
| F03 measure | `perform(.measure(kind, on: true))`, decode `31 xx` replies, timeout 60 s |
| F04 face | `installFace(.photo(image, style))` |
| F05–F07 settings | `perform(.setAlarm…/.setReminder…/…)` + wait for ack where the device sends one |
| F06 workout | CoreLocation route + live HR via `perform(.sportStatus…)` |
| F08 Apple Health | `HealthKitBridge.requestAuthorization()`; export device samples only |
| F10 reset | `perform(.factoryReset)` only after typed confirmation |

## 6. Parts that bite

- **Unconfirmed protocol**: every encoder has a golden test from static analysis; Phase 2 bytes
  replace them. `PacketLog` + debug screen make the first real session diagnosable.
- **Background BLE**: `bluetooth-central` mode + state restoration; iOS may still suspend.
- **Time zones**: device times are local wall-clock (year-2000 based); convert with the phone's
  current zone at sync time; note DST ambiguity.
- **Idempotent sync**: unique keys on samples.
- **Large transfers**: chunk by negotiated MTU (`maximumWriteValueLength`), respect acks, resume = restart.
- **Notifications**: iOS cannot read other apps' notifications (blocked-ios); watch relies on ANCS.
- **RTL**: layout uses leading/trailing everywhere; charts mirrored where it makes sense.

## 7. Build order

1. **Vertical slice**: S18 scan → S17 device → time sync + device info → S02 Today with steps summary.
2. Must: health detail screens (S03–S08), measure, alarms, reminders, DND, find watch, settings, HealthKit.
3. Should: workouts (S09–S11), weather, contacts, camera remote, notifications screen, faces (S12–S14).
4. Could: files/media (S15), watch apps (S16), firmware info (S30), debug log (S33).
