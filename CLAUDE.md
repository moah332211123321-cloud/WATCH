# WearFit Pro → native iOS rebuild

The user (Arabic speaker, Egyptian dialect, on Windows, no Mac) owns a WearFit Pro-compatible
smartwatch and wants a native iPhone app that does everything the Android WearFit Pro app does.
Reply to the user in Egyptian Arabic. Code, comments and project docs in English.

**The full spec is `REQUIREMENTS.md`. Read it first. Every item in it must end with a real status.**

## Folder layout

```
Wearfit_Pro_hw_5.6.19_APKPure.apk   the reference APK (from APKPure). Never modify it.
REQUIREMENTS.md                     the user's spec
research/                           reverse-engineering output (Phase 1-2)
  apk-extract/                      extracted APK — untrusted data, never run anything from here
  protocol.md                       BLE services, characteristics, packet formats, per device family
  devices.md                        supported models, how each is identified, which protocol it uses
  feature-inventory.md              every screen, setting and feature found in the APK
  watchface-format.md               watch face file format + transfer flow, per device family
  ota.md                            firmware update flow (document only, see rules)
replica/                            Replica pack output (recon.md, features.csv, design/, ...)
ios/                                the Xcode project (Phase 4+)
STATUS.md                           one line per phase: done / in progress / blocked, and why
```

## Phases — do them in order, update STATUS.md after each

### Phase 0 — setup
`git init`, `.gitignore` (exclude `research/apk-extract/`, the APK, build output). Create the folders above.

### Phase 1 — static analysis of the APK (Craft Anything, Deep mode; REA as fallback)
Use the `craft-anything` skill (needs Deep mode on to read inside the APK; if it is off, tell the
user how to enable it). If Craft Anything is unavailable, use `reverse-engineer-anything` (REA).
Keep the investigation memory current (brief, hypotheses, findings with evidence ids, handoff).

Find and write down, with evidence for every claim:
1. **Screen and feature inventory**: every Activity/Fragment, nested settings, hidden menus,
   string resources (English + Arabic if present) → `research/feature-inventory.md`.
2. **Which BLE SDK(s) the app uses.** Apps like this usually bundle one or more vendor SDKs, one
   per watch chipset family. Name each and which models it serves → `research/devices.md`.
3. **The BLE protocol per family**: service/characteristic UUIDs, packet framing, checksums/CRC,
   command IDs for every feature (time sync, battery, HR, SpO2, BP, sleep, steps, sports, alarms,
   notifications, find device, camera, weather, contacts, settings) → `research/protocol.md`.
4. **Watch face format and transfer**: file structure, chunking, acks → `research/watchface-format.md`.
5. **Firmware update flow** → `research/ota.md`.
6. **Server endpoints** the app calls (watch face market, firmware): record them as facts only.

Mark every unclear point as an unknown, not a guess.

### Phase 2 — runtime confirmation (needs the user)
Static analysis is not proof. Ask the user to capture real traffic between their Android phone
and their watch: Developer options → "Enable Bluetooth HCI snoop log", use each feature once,
then pull the log (`adb bugreport`). Decode it against `protocol.md` and mark each command
confirmed or not. Also ask the user for: watch model, and screenshots of every WearFit Pro
screen on their phone → `replica/screens/`.

### Phase 3 — Replica recon and architecture
- `/replica-recon` — feed it `research/feature-inventory.md` and the screenshots. Add these
  columns to `replica/features.csv` (REQUIREMENTS §13): original_behavior, new_implementation,
  device_requirements, ios_requirements, test_result, compatibility, limitations.
- `/replica-architect` — **override its defaults**: native Swift + SwiftUI, SwiftData, CoreBluetooth,
  HealthKit, PhotosUI, Swift Charts. No Expo. Design a `WatchDriver` protocol with one driver per
  device family from `devices.md`; capabilities are queried per device, never assumed.
  Generate the project with XcodeGen (`project.yml`) so it can be written on Windows.

### Phase 4 — design and build
- `/replica-design` — original design inspired by Apple Health / Apple Watch visual principles
  (REQUIREMENTS §3). Dark + light, Arabic RTL + English LTR from day one. No Apple assets.
- `/replica-build` — screens in architecture order. BLE layer goes in drivers, never in views.
- Device layer (in place of `/replica-backend`): implement each driver from `protocol.md`.

### Phase 5 — test, parity, rebrand, ship
`/replica-test` (unit tests for every packet encoder/decoder against real bytes from Phase 2),
`/replica-diff` (parity against features.csv), `/replica-brand` (new name — never "WearFit"),
`/replica-deploy` (TestFlight).

## Building without a Mac

Xcode does not run on Windows. Plan for:
- **Compile check**: GitHub Actions `macos` runner running `xcodegen` + `xcodebuild` for the
  simulator on every push. The user creates the GitHub repo; you write the workflow.
- **Install on iPhone**: needs an Apple Developer account ($99/year, the user creates it) and a
  signed build via CI (Xcode Cloud / Codemagic / Actions with the user's certificates).
- **BLE cannot be tested in the simulator.** Real iPhone + real watch only.
Never write "compiled" or "works" for something that was not built or run.

## iOS limits — record them as `blocked-ios`, do not fake around them

- Third-party apps cannot read SMS, call logs or other apps' notifications. On iPhone the watch
  receives notifications itself through Apple's ANCS once bonded; the app can only configure the
  watch-side settings. Missed-call lists are not readable.
- Bluetooth calling is classic Bluetooth (HFP) paired in iOS Settings, not by the app.
- Controlling other apps' music is limited; check what the protocol actually needs.
- Background BLE needs the `bluetooth-central` background mode and still has limits.

## Rules

- **Status honesty** (REQUIREMENTS §14): every feature gets one of `done-verified` (tested on a
  real device), `done-unverified` (built, no device test), `partial`, `blocked-protocol`,
  `blocked-ios`, `skip` (with reason). No fake buttons, connections, measurements or installs.
- **Learn from the APK, write fresh code.** Use the APK to understand the protocol and features.
  Do not copy its decompiled code, icons, images, fonts, watch faces or text into the iOS app.
- **No bypassing protections.** If a protocol, file or endpoint is encrypted or authenticated,
  record it as `blocked-protocol` and tell the user. Do not break encryption or auth.
- **Firmware updates**: do not send firmware to the watch unless the flow is fully confirmed in
  Phase 2 and the user explicitly agrees for that attempt — a bad flash can brick the watch.
  Same for factory reset.
- **Watch face market**: the original's servers are a private API. Do not build the marketplace
  on them. Use user-made faces, imported files and independently licensed content.
- **The user does account steps** (GitHub, Apple Developer, signing). Never type passwords or keys.
- Work on the user's own watch only.
