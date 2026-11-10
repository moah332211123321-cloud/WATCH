# Status

| Phase | State | Notes |
|---|---|---|
| 0 — setup | done | git repo, `.gitignore` (APK, `research/apk-extract/`, build output), folders `research/ replica/ ios/` |
| 1 — static analysis | done (with tooling limits) | `research/protocol.md`, `devices.md`, `feature-inventory.md`, `watchface-format.md`, `ota.md`; evidence in `research/evidence/`. Craft Anything was in Clean room (Deep mode off) and REA had no JADX/apktool/JDK, so the APK was read with stdlib parsers in `research/tools/` (no decompiled source). Not covered: React Native (Hermes) bundle screens; byte layouts of sleep/sport/history/device-info records; dynamically built packets. |
| 2 — runtime confirmation | blocked — needs the user | need: watch model + photo of its "About" screen, Android HCI snoop log (bugreport) while using each feature once, screenshots of every WearFit Pro screen → `replica/screens/` |
| 3 — recon + architecture | not started | waits for Phase 2 |
| 4 — design + build | not started | |
| 5 — test, parity, rebrand, ship | not started | |
