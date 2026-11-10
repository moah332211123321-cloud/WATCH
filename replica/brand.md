# Brand

## Name

Angle: an honest, private (no account, no vendor cloud), Arabic-first companion for the user's watch.

Candidates (20): Sawar, Daqqa, Rasd, Mizan, Wasla, Watan-Fit (cut: "Fit" echo), Nabd (cut: existing
Arabic news app "Nabd"), Hilal, Sahm, Ritm, Qalb, Mada, Halaqa, Tick&Pulse, Wristlog, Pulsewise,
Bandly (cut: "-ly"), Kord, Leen, Saaa (cut: unspellable).

Shortlist: **Sawar** (سوار, "bracelet / wristband"), Daqqa (دقّة, "beat" and "precision"), Rasd
(رصد, "tracking"), Mizan (ميزان, "balance"), Halaqa (حلقة, "ring").

**Chosen for the build: Sawar** — short, spellable in both scripts, says "on your wrist", no
similarity to the original's name. Bundle id placeholder: `app.sawar.ios` (the user picks the real one).

| check | Sawar | Daqqa | Rasd | Mizan | Halaqa |
|---|---|---|---|---|---|
| US trademark (USPTO, class 9/42) | to run | to run | to run | to run | to run |
| EU trademark (EUIPO / TMview) | to run | to run | to run | to run | to run |
| WIPO Global Brand DB (incl. Egypt) | to run | to run | to run | to run | to run |
| domain | to run | to run | to run | to run | to run |
| App Store / Play exact name | to run | to run | to run | to run | to run |
| handles | to run | to run | to run | to run | to run |
| web "name + smartwatch" | to run | to run | to run | to run | to run |

None of these checks has been run. They are screening checks, not legal clearance.

## Palette

Primary hue: deep teal `#0b7a75` (light) / `#3fd2c7` (dark) — different family from the vendor app.
Metric colours are our own set. Tokens: `replica/design/tokens.json`, `tokens-dark.json`; contrast
report: 36 pairs, 0 AA failures.

## Logo brief

- Idea: a closed band seen from above that is also a heartbeat line — "the bracelet that listens".
- Mark: symbol + wordmark (Latin "Sawar", Arabic "سوار"); the symbol alone is the app icon.
- Must read at 16 px and at 1024 px; iOS icon 1024×1024, no transparency; SVG master.
- Must not resemble the vendor's mark (no shared shape, colour pair or letterform trick).
- Status: brief only; the app ships a placeholder icon until the user provides one.

## Voice

Calm (not cold), clear (not technical), honest (not alarming).

| do | don't |
|---|---|
| "Your watch didn't answer. Try again?" | "Error 0x92 timeout" |
| "Not supported on this watch" | hide the button |
| "Saved on the watch" (after the watch confirms) | "Done!" before the ack |
| "Estimated" next to estimates | present estimates as measurements |
| short sentences, Arabic first-class | literal machine translation |

Key strings (en / ar) live in `ios/App/Resources/Localizable.xcstrings`, written fresh.

## Sweep

`replica/brand.json` lists names, domains and colours that must not appear in the app code.
Run: `python3 ~/.claude/skills/replica-brand/sweep.py ios --config replica/brand.json`.
