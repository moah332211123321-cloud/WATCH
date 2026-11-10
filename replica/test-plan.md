# Test plan

## 1. Automated (runs in GitHub Actions, `.github/workflows/ios.yml`)

- `swift test` in `ios/Packages/WatchCore`: framing, reassembly, CRC-16/MODBUS, RGB565, every encoder
  (golden bytes from the APK's templates), every decoder (bytes built from derived layouts), driver
  (handshake, timeout, consent gate, heartbeat reply, chunking, refusal of unconfirmed face/firmware).
- `xcodebuild test` on an iOS simulator: `HealthRepositoryTests` (no duplicates on re-sync, live values not
  stored, manual source kept, day summary updated not duplicated).
- `ios/l10n/build_strings.py`: fails if any UI string lacks Arabic.

**Status: none of these has run yet.** Phase 2 will replace golden bytes with captured ones.

## 2. On the real iPhone + the user's watch (needs a signed build)

Open the hidden packet log first (Watch tab → tap the version line 5 times), then:

| # | flow | expected | record |
|---|---|---|---|
| 1 | Scan, connect | watch listed with RSSI; "Connected"; firmware version shown | packet log export |
| 2 | Pull to refresh on Today | steps / kcal appear and match the watch | screenshot + log |
| 3 | Measure heart rate | value within 60 s, matches watch screen | log |
| 4 | Measure SpO2, BP | same | log |
| 5 | Find my watch | watch vibrates/rings | — |
| 6 | Alarm 07:30 Mon–Fri | appears correctly on the watch | photo of watch |
| 7 | Sedentary, water, DND | appear on the watch | photo |
| 8 | Raise to wake, 12 h, °F | watch changes | photo |
| 9 | Phone-led run (5 min outside) | route, distance, HR | screenshot |
| 10 | Apple Health export | samples appear in Health app with source Sawar | screenshot |
| 11 | Arabic + dark mode | every screen readable, mirrored | screenshots |
| 12 | Factory reset (only if the user agrees) | — | do not run by default |

Each row becomes `done-verified` in `features.csv` only after it passes on the real watch.
