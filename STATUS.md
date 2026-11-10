# Status

| Phase | State | Notes |
|---|---|---|
| 0 — setup | done | git repo, `.gitignore`, `.gitattributes`, folder layout |
| 1 — static analysis | done (tooling-limited) | `research/*.md` + `research/evidence/`. Craft Anything in Clean room, REA without JADX/apktool/JDK → stdlib DEX parsers (`research/tools/`). Second pass added device-info, capability bits, sync requests, sleep and HR layouts. Not covered: React Native (Hermes) screens, sport records, dynamic packets. Installing JADX was not done (needs the user's OK to download). |
| 2 — runtime confirmation | blocked — needs the user | watch model, HCI snoop log, screenshots. Every command is **unconfirmed**. |
| 3 — recon + architecture | done | `replica/recon.md` (33 screens, 10 flows), `replica/architecture.md` (Swift/SwiftUI/SwiftData/XcodeGen, WatchDriver + family plug-ins) |
| 4 — design + build | done-unverified | tokens (0 AA failures), brand "Sawar", WatchCore package + 33-screen app, en+ar (232 keys). **Compiles** in CI (run 42864759178, macos-latest, simulator, unsigned). Not run on a real iPhone or watch. |
| 5 — test, parity, rebrand, ship | partial | 43 unit tests pass in CI (run 42864759178); parity 68.5/100 built-in-code, 0 verified (`replica/parity.md`); brand sweep clean; CI green on every push; TestFlight blocked on the user's Apple Developer account and signing. |
