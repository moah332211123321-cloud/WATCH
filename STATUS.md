# Status

| Phase | State | Notes |
|---|---|---|
| 0 — setup | done | git repo, `.gitignore`, `.gitattributes`, folder layout |
| 1 — static analysis | done (tooling-limited) | `research/*.md` + `research/evidence/`. Craft Anything in Clean room, REA without JADX/apktool/JDK → stdlib DEX parsers (`research/tools/`). Second pass added device-info, capability bits, sync requests, sleep and HR layouts. Third pass with JADX 1.5.6 decompile (set up by the coordinating session): photo-face transfer, acks, screen size + table, platform byte, sport records (`B7`). Not covered: React Native (Hermes) screens, many dynamic packets. |
| 2 — runtime confirmation | in progress — via the iPhone | Watch: urjwanplus, fw 1.02. No Android phone, so no HCI snoop: Sawar's Bluetooth log (Watch tab → Developer → Export) replaces it. Sawar runs on the user's iPhone (sideloaded unsigned IPA). Every command is still **unconfirmed** until a log comes back. |
| 3 — recon + architecture | done | `replica/recon.md` (33 screens, 10 flows), `replica/architecture.md` (Swift/SwiftUI/SwiftData/XcodeGen, WatchDriver + family plug-ins) |
| 4 — design + build | done-unverified | tokens (0 AA failures), brand "Sawar", WatchCore package + 33-screen app, en+ar (265 keys), 100 original watch-face designs, experimental photo-face install. **Compiles** in CI (run 42864759178, macos-latest, simulator, unsigned). Not run on a real iPhone or watch. |
| 5 — test, parity, rebrand, ship | partial | 57 unit tests (see latest CI run); parity 71.7/100 built-in-code, 0 verified (`replica/parity.md`); brand sweep clean; CI green on every push; TestFlight blocked on the user's Apple Developer account and signing. |
